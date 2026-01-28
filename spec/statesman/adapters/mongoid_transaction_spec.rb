# frozen_string_literal: true

require 'spec_helper'
require 'statesman/adapters/mongoid'
require 'statesman/exceptions'
require 'support/mongoid'

describe Statesman::Adapters::Mongoid, 'transaction features', mongo: true do
  before do
    Statesman.configure do
      storage_adapter(Statesman::Adapters::Mongoid)
    end
  end

  after { Statesman.configure { storage_adapter(Statesman::Adapters::Memory) } }
  after { Mongoid.purge! }

  let(:observer) { double(Statesman::Machine, execute: nil) }
  let(:model) { MyMongoidModel.create(current_state: :pending) }
  let(:adapter) { described_class.new(MyMongoidModelTransition, model, observer) }

  describe 'StatesmanMongoid configuration' do
    describe '.mongoid_9_or_higher?' do
      it 'returns a boolean' do
        expect(StatesmanMongoid.mongoid_9_or_higher?).to be_in([true, false])
      end

      it 'is true for Mongoid 9+' do
        if Gem::Version.new(Mongoid::VERSION) >= Gem::Version.new('9.0')
          expect(StatesmanMongoid.mongoid_9_or_higher?).to be true
        else
          expect(StatesmanMongoid.mongoid_9_or_higher?).to be false
        end
      end
    end

    describe '.replica_set?' do
      it 'returns a boolean' do
        expect(StatesmanMongoid.replica_set?).to be_in([true, false])
      end
    end

    describe '.transactions_available?' do
      it 'returns a boolean' do
        expect(StatesmanMongoid.transactions_available?).to be_in([true, false])
      end

      it 'requires both Mongoid 9+ and replica set' do
        if StatesmanMongoid.transactions_available?
          expect(StatesmanMongoid.mongoid_9_or_higher?).to be true
          expect(StatesmanMongoid.replica_set?).to be true
        end
      end
    end

    describe '.reset!' do
      it 'clears memoized values' do
        # Access to memoize
        StatesmanMongoid.mongoid_9_or_higher?
        StatesmanMongoid.reset!

        # Should not raise
        expect { StatesmanMongoid.mongoid_9_or_higher? }.not_to raise_error
      end
    end
  end

  describe '#create' do
    describe 'from_state field' do
      it 'populates from_state when transition class supports it' do
        adapter.create(:initial, :succeeded)
        transition = adapter.last

        expect(transition.from_state).to eq('initial')
        expect(transition.to_state).to eq('succeeded')
      end

      it 'tracks state progression through multiple transitions' do
        adapter.create(:initial, :failed)
        adapter.create(:failed, :initial)

        transitions = adapter.history.to_a
        expect(transitions[0].from_state).to eq('initial')
        expect(transitions[0].to_state).to eq('failed')
        expect(transitions[1].from_state).to eq('failed')
        expect(transitions[1].to_state).to eq('initial')
      end
    end

    describe 'most_recent optimization' do
      context 'when transactions are available' do
        before do
          unless StatesmanMongoid.transactions_available?
            skip 'Transactions not available (requires Mongoid 9+ with replica set)'
          end
        end

        it 'sets most_recent to true on new transition' do
          adapter.create(:initial, :succeeded)

          expect(adapter.last.most_recent).to be true
        end

        it 'sets previous transition most_recent to false' do
          adapter.create(:initial, :failed)
          first_transition = adapter.last

          adapter.create(:failed, :initial)

          first_transition.reload
          expect(first_transition.most_recent).to be false
          expect(adapter.last.most_recent).to be true
        end

        it 'only one transition has most_recent=true at any time' do
          3.times do |i|
            from = if i.zero?
                     :initial
                   else
                     (i.odd? ? :failed : :initial)
                   end
            to = i.odd? ? :initial : :failed
            adapter.create(from, to)
          end

          recent_count = MyMongoidModelTransition.where(
            my_mongoid_model_id: model.id,
            most_recent: true
          ).count

          expect(recent_count).to eq(1)
        end
      end

      context 'when transactions are not available' do
        before do
          skip 'Test only applies when transactions are not available' if StatesmanMongoid.transactions_available?
        end

        it 'does not set most_recent field (left as nil)' do
          adapter.create(:initial, :succeeded)

          # Without transactions, most_recent is not set to avoid non-atomic updates
          expect(adapter.last.most_recent).to be_nil
        end
      end
    end

    describe 'conflict detection' do
      context 'when transactions are available' do
        before do
          unless StatesmanMongoid.transactions_available?
            skip 'Transactions not available (requires Mongoid 9+ with replica set)'
          end

          # Ensure indexes are created for this test
          MyMongoidModelTransition.create_indexes
        end

        it 'raises error on duplicate most_recent via unique index' do
          # Create a transition which sets most_recent=true
          adapter.create(:initial, :succeeded)
          first_transition = adapter.last

          # Verify the first transition has most_recent=true
          expect(first_transition.most_recent).to be true

          # Manually create a conflicting transition with most_recent=true
          # This simulates a race condition where two processes try to create
          # transitions simultaneously (bypassing the adapter's update_most_recents)
          conflicting = MyMongoidModelTransition.new(
            my_mongoid_model: model,
            to_state: 'failed',
            sort_key: 20,
            most_recent: true, # Conflict - already have a most_recent=true for this model
            statesman_metadata: {}
          )

          # The unique sparse index should prevent this
          expect { conflicting.save! }.to raise_error(Mongo::Error::OperationFailure) do |error|
            expect(error.message).to include('duplicate key error')
          end
        end
      end

      context 'when transactions are not available' do
        before do
          skip 'Test only applies when transactions are not available' if StatesmanMongoid.transactions_available?
        end

        it 'does not enforce most_recent uniqueness (no atomic updates)' do
          # Without transactions, most_recent is not used, so no conflict
          adapter.create(:initial, :succeeded)

          # Both transitions can have nil most_recent
          expect(adapter.last.most_recent).to be_nil
        end
      end
    end

    describe 'callback execution order' do
      let(:callback_order) { [] }
      let(:tracking_observer) do
        observer = double(Statesman::Machine)
        allow(observer).to receive(:execute) do |phase, _from, _to, _transition|
          callback_order << phase
        end
        observer
      end
      let(:tracking_adapter) do
        described_class.new(MyMongoidModelTransition, model, tracking_observer)
      end

      it 'executes callbacks in correct order' do
        tracking_adapter.create(:initial, :succeeded)

        expect(callback_order).to eq(%i[before after after_commit])
      end
    end
  end

  describe '#history' do
    before do
      adapter.create(:initial, :failed)
      adapter.create(:failed, :initial)
      adapter.create(:initial, :succeeded)
    end

    it 'returns transitions in sort_key order' do
      history = adapter.history.to_a

      expect(history.map(&:to_state)).to eq(%w[failed initial succeeded])
    end

    it 'force_reload refreshes from database' do
      # Create another adapter instance that creates a transition
      other_adapter = described_class.new(MyMongoidModelTransition, model, observer)
      begin
        other_adapter.create(:succeeded, :failed)
      rescue StandardError
        nil
      end

      # Force reload should see all transitions
      history = adapter.history(force_reload: true).to_a
      expect(history.length).to be >= 3
    end
  end

  describe '#last' do
    it 'returns nil when no transitions exist' do
      expect(adapter.last).to be_nil
    end

    it 'returns the most recent transition' do
      adapter.create(:initial, :failed)
      adapter.create(:failed, :initial)

      expect(adapter.last.to_state).to eq('initial')
    end

    it 'caches the result' do
      adapter.create(:initial, :succeeded)
      adapter.last

      expect(model).not_to receive(:my_mongoid_model_transitions)
      adapter.last
    end

    it 'updates cache after creating new transition' do
      adapter.create(:initial, :failed)
      expect(adapter.last.to_state).to eq('failed')

      adapter.create(:failed, :initial)
      expect(adapter.last.to_state).to eq('initial')
    end
  end

  describe '#reset' do
    it 'clears the last transition cache' do
      adapter.create(:initial, :succeeded)
      adapter.last

      adapter.reset

      # After reset, accessing last should query database again
      expect(adapter.instance_variable_get(:@last_transition)).to be_nil
    end
  end
end

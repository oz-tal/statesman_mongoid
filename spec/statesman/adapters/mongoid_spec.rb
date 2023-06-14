require "spec_helper"
require "statesman/adapters/mongoid"
require "statesman/exceptions"
require "support/mongoid"

# statesman generic adapter spec
statesman_dir = Gem::Specification.find_by_name("statesman").gem_dir
require File.join(statesman_dir, "spec/statesman/adapters/shared_examples")

describe Statesman::Adapters::Mongoid, mongo: true do
  before do
    Statesman.configure do
      # Rubocop requires described_class to be used, but this block
      # is instance_eval'd and described_class won't be defined
      # rubocop:disable RSpec/DescribedClass
      storage_adapter(Statesman::Adapters::Mongoid)
      # rubocop:enable RSpec/DescribedClass
    end
  end

  after { Statesman.configure { storage_adapter(Statesman::Adapters::Memory) } }
  after { Mongoid.purge! }

  let(:observer) { double(Statesman::Machine, execute: nil) }
  let(:model) { MyMongoidModel.create(current_state: :pending) }

  it_behaves_like "an adapter", described_class, MyMongoidModelTransition

  describe "#initialize" do
    context "with unserialized metadata" do
      before do
        allow_any_instance_of(described_class).
          to receive_messages(transition_class_hash_fields: [])
      end

      it "raises an exception if metadata is not serialized" do
        expect do
          described_class.new(MyMongoidModelTransition, MyMongoidModel,
                              observer)
        end.to raise_exception(Statesman::UnserializedMetadataError)
      end
    end
  end

  describe "#last" do
    let(:adapter) do
      described_class.new(MyMongoidModelTransition, model, observer)
    end

    context "with a previously looked up transition" do
      before { adapter.create(:x, :y) }

      before { adapter.last }

      it "caches the transition" do
        expect_any_instance_of(MyMongoidModel).
          to_not receive(:my_mongoid_model_transitions)
        adapter.last
      end

      context "and a new transition" do
        before { adapter.create(:y, :z) }

        it "retrieves the new transition from the database" do
          expect(adapter.last.to_state).to eq("z")
        end
      end
    end

    context "when a new transition has been created elsewhere" do
      let(:alternate_adapter) do
        described_class.new(MyMongoidModelTransition, model, observer)
      end

      context "when explicitly not using the cache" do
        context "when the transitions are in memory" do
          before do
            model.my_mongoid_model_transitions.entries
            alternate_adapter.create(:y, :z)
          end

          it "reloads the value" do
            expect(adapter.last(force_reload: true).to_state).to eq("z")
          end
        end

        context "when the transitions are not in memory" do
          before do
            model.my_mongoid_model_transitions.reset
            alternate_adapter.create(:y, :z)
          end

          it "reloads the value" do
            expect(adapter.last(force_reload: true).to_state).to eq("z")
          end
        end
      end
    end
  end
end

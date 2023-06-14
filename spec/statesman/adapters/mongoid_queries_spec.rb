# frozen_string_literal: true

require "spec_helper"
require "statesman/adapters/mongoid_queries"

describe Statesman::Adapters::MongoidQueries, mongo: true do
  def configure_old(klass, transition_class)
    klass.define_singleton_method(:transition_class) { transition_class }
    klass.define_singleton_method(:initial_state) { :initial }
    klass.send(:include, described_class)
  end

  def configure_new(klass, transition_class)
    klass.send(:include, described_class[transition_class: transition_class,
                                         initial_state: :initial])
  end

  before do
    Statesman.configure do
      storage_adapter(Statesman::Adapters::Mongoid)
    end
  end

  after { Statesman.configure { storage_adapter(Statesman::Adapters::Memory) } }

  let!(:model) do
    model = MyMongoidModel.create
    model.state_machine.transition_to(:succeeded)
    model
  end

  let!(:other_model) do
    model = MyMongoidModel.create
    model.state_machine.transition_to(:failed)
    model
  end

  let!(:initial_state_model) { MyMongoidModel.create }

  let!(:returned_to_initial_model) do
    model = MyMongoidModel.create
    model.state_machine.transition_to(:failed)
    model.state_machine.transition_to(:initial)
    model
  end

  shared_examples "testing methods" do
    before do
      case config_type
      when :old
        configure_old(MyMongoidModel, MyMongoidModelTransition)
        configure_old(OtherMongoidModel, OtherMongoidModelTransition)
      when :new
        configure_new(MyMongoidModel, MyMongoidModelTransition)
        configure_new(OtherMongoidModel, OtherMongoidModelTransition)
      else
        raise "Unknown config type #{config_type}"
      end

      MyMongoidModel.send(:has_one, :other_mongoid_model)
      OtherMongoidModel.send(:belongs_to, :my_mongoid_model)
    end

    describe ".in_state" do
      context "given a single state" do
        subject { MyMongoidModel.in_state(:succeeded) }

        it { is_expected.to include model }
        it { is_expected.to_not include other_model }
      end

      context "given multiple states" do
        subject { MyMongoidModel.in_state(:succeeded, :failed) }

        it { is_expected.to include model }
        it { is_expected.to include other_model }
      end

      context "given the initial state" do
        subject { MyMongoidModel.in_state(:initial) }

        it { is_expected.to include initial_state_model }
        it { is_expected.to include returned_to_initial_model }
      end

      context "given an array of states" do
        subject { MyMongoidModel.in_state(%i[succeeded failed]) }

        it { is_expected.to include model }
        it { is_expected.to include other_model }
      end
    end

    describe ".not_in_state" do
      context "given a single state" do
        subject { MyMongoidModel.not_in_state(:failed) }

        it { is_expected.to include model }
        it { is_expected.to_not include other_model }
      end

      context "given multiple states" do
        subject(:not_in_state) { MyMongoidModel.not_in_state(:succeeded, :failed) }

        it do
          expect(not_in_state).to contain_exactly(initial_state_model,
                                                  returned_to_initial_model)
        end
      end

      context "given an array of states" do
        subject(:not_in_state) { MyMongoidModel.not_in_state(%i[succeeded failed]) }

        it do
          expect(not_in_state).to contain_exactly(initial_state_model,
                                                  returned_to_initial_model)
        end
      end
    end

    context "with a custom name for the transition association" do
      before do
        # Switch to using OtherMongoidModelTransition, so the existing
        # relation with MyMongoidModelTransition doesn't interfere with
        # this spec.
        MyMongoidModel.send(:has_many,
                                 :custom_name,
                                 class_name: "OtherMongoidModelTransition")

        MyMongoidModel.class_eval do
          def self.transition_class
            OtherMongoidModelTransition
          end
        end
      end

      describe ".in_state" do
        subject(:query) { MyMongoidModel.in_state(:succeeded) }

        specify { expect { query }.to_not raise_error }
      end
    end

    context "with a custom primary key for the model" do
      before do
        # Switch to using OtherMongoidModelTransition, so the existing
        # relation with MyMongoidModelTransition doesn't interfere with
        # this spec.
        # Configure the relationship to use a different primary key,
        MyMongoidModel.send(:has_many,
                                 :custom_name,
                                 class_name: "OtherMongoidModelTransition",
                                 primary_key: :external_id)

        MyMongoidModel.class_eval do
          def self.transition_class
            OtherMongoidModelTransition
          end
        end
      end

      describe ".in_state" do
        subject(:query) { MyMongoidModel.in_state(:succeeded) }

        specify { expect { query }.to_not raise_error }
      end
    end

    # TODO: This test require a mongoid replica set and doesn't work with a standalone server.
    #       It currently never ran and will require some further investigation.
    # context "after_commit transactional integrity" do
    #   before do
    #     MyStateMachine.class_eval do
    #       cattr_accessor(:after_commit_callback_executed) { false }

    #       after_transition(from: :initial, to: :succeeded, after_commit: true) do
    #         # This leaks state in a testable way if transactional integrity is broken.
    #         MyStateMachine.after_commit_callback_executed = true
    #       end
    #     end
    #   end

    #   after do
    #     MyStateMachine.class_eval do
    #       callbacks[:after_commit] = []
    #     end
    #   end

    #   let!(:model) do
    #     MyMongoidModel.create
    #   end

    #   it do
    #     expect do
    #       model.with_session do |session|
    #         session.start_transaction
    #         model.state_machine.transition_to!(:succeeded)
    #         raise Mongoid::Errors::Rollback
    #       end
    #     end.to_not change(MyStateMachine, :after_commit_callback_executed)
    #   end
    # end
  end

  context "using old configuration method" do
    let(:config_type) { :old }

    include_examples "testing methods"
  end

  context "using new configuration method" do
    let(:config_type) { :new }

    include_examples "testing methods"
  end

  context "with no association with the transition class" do
    before do
      class UnknownModelTransition < OtherMongoidModelTransition; end

      configure_old(MyMongoidModel, UnknownModelTransition)
    end

    describe ".in_state" do
      subject(:query) { MyMongoidModel.in_state(:succeeded) }

      it "raises a helpful error" do
        expect { query }.to raise_error(Statesman::MissingTransitionAssociation)
      end
    end
  end

  describe "check_missing_methods!" do
    subject(:check_missing_methods!) { described_class.check_missing_methods!(base) }

    context "when base has no missing methods" do
      let(:base) do
        Class.new do
          def self.transition_class; end

          def self.initial_state; end
        end
      end

      it "does not raise an error" do
        expect { check_missing_methods! }.to_not raise_exception
      end
    end

    context "when base has missing methods" do
      let(:base) do
        Class.new
      end

      it "raises an error" do
        expect { check_missing_methods! }.to raise_exception(NotImplementedError)
      end
    end
  end
end

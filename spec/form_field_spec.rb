require File.dirname(__FILE__) + '/spec_helper'

describe VoiceForm::FormField do
  include VoiceForm::FormMethods

  attr_accessor :call, :my_field

  before do
    @call = mock('Call', :play => nil, :speak => nil)
    @call.stub!(:input).with(any_args).and_return('')
  end

  it "should define accessor for field in component" do
    field(:my_field) do
      prompt :play => 'test'
    end
    self.methods.include?(:my_field)
  end

  it "should raise error if no prompts defined" do
    lambda {
      form_field(:my_field) {}
    }.should raise_error
  end

  it "should raise error if reprompt defined before prompt" do
    lambda {
      form_field(:my_field) do
        reprompt :play => 'again'
      end
     }.should raise_error
  end

  it "should return same prompt for for all attempts if single prompt" do
    item = form_field(:my_field) do
      prompt :play => "first"
    end
    item.send(:prompt_for_attempt, 1)[:message].should == 'first'
    item.send(:prompt_for_attempt, 2)[:message].should == 'first'
  end

  it "should return reprompt for subsequent prompts" do
    item = form_field(:my_field) do
      prompt :play => "first"
      reprompt :play => 'next'
    end
    item.send(:prompt_for_attempt, 1)[:message].should == 'first'
    item.send(:prompt_for_attempt, 2)[:message].should == 'next'
    item.send(:prompt_for_attempt, 3)[:message].should == 'next'
  end

  it "should return prompt for given number of repeats before subsequent prompts" do
    item = form_field(:my_field) do
      prompt :play => "first", :repeats => 2
      reprompt :play => 'next'
    end
    item.send(:prompt_for_attempt, 1)[:message].should == 'first'
    item.send(:prompt_for_attempt, 2)[:message].should == 'first'
    item.send(:prompt_for_attempt, 3)[:message].should == 'next'
  end

  it "should set input value in component" do
    item = form_field(:my_field, :length => 3) do
      prompt :play => "first"
    end
    call.stub!(:input).and_return('123')
    item.run

    my_field.should == '123'
  end

  it "should run setup callback once" do
    call_me = i_should_be_called
    item = form_field(:my_field, :attempts => 3) do
      prompt :play => "first"
      setup { call_me.call }
    end
    call.should_receive(:input).and_return('')

    item.run
  end

  it "should run timeout callback if no input" do
    call_me = i_should_be_called
    item = form_field(:my_field, :attempts => 1) do
      prompt :play => "first"
      timeout { call_me.call }
    end
    call.should_receive(:input).and_return('')

    item.run
  end

  it "should run timeout callback if input not valid length" do
    call_me = i_should_be_called
    item = form_field(:my_field, :attempts => 1, :length => 3) do
      prompt :play => "first"
      timeout { call_me.call }
    end
    call.should_receive(:input).and_return('12')

    item.run
  end

  it "should make all attempts to get valid input" do
    item = form_field(:my_field) do
      prompt :play => "first"
    end
    call.should_receive(:input).exactly(3).times

    item.run
  end

  it "should make one attempt if input is valid" do
    item = form_field(:my_field) do
      prompt :play => "first"
    end
    item.stub!(:input_valid?).and_return(true)
    call.should_receive(:input).once

    item.run
  end

  it "should check if input_valid?" do
    item = form_field(:my_field, :length => 3) do
      prompt :play => "first"
    end
    call.should_receive(:input).and_return('123')
    item.should_receive(:input_valid?)

    item.run
  end

  it "should run validation callback if defined" do
    call_me = i_should_be_called
    item = form_field(:my_field, :length => 3, :attempts => 1) do
      prompt :play => "first"
      validate { call_me.call }
    end
    call.stub!(:input).and_return('123')

    item.run
  end

  it "should run confirm callback if defined" do
    call_me = i_should_be_called
    item = form_field(:my_field, :length => 3, :attempts => 1) do
      prompt :play => "first"
      confirm { call_me.call; [] }
    end
    call.stub!(:input).and_return('123')

    item.run
  end

  describe "confirm callback" do

    it "should not run if not valid input" do
      dont_call_me = i_should_not_be_called
      item = form_field(:my_field, :length => 3, :attempts => 1) do
        prompt :play => "first"
        validate { false }
        confirm { dont_call_me.call }
      end
      call.stub!(:input).and_return('123')

      item.run
    end

    it "should be run the number of attempts if no valid response" do
      call.should_receive(:input).with(3, anything).and_return('123')
      item = form_field(:my_field, :length => 3, :attempts => 1) do
        prompt :play => "first"

        confirm(:attempts => 3) { [] }
      end
      call.should_receive(:input).with(1, anything).exactly(3).times.and_return('')

      item.run
    end

    it "should run success callback if accept value entered" do
      call_me = i_should_be_called
      call.should_receive(:input).with(3, anything).and_return('123')
      item = form_field(:my_field, :length => 3, :attempts => 1) do
        prompt :play => "first"

        success { call_me.call }
        confirm(:accept => '1', :reject => '2') { [] }
      end
      call.should_receive(:input).with(1, anything).and_return('1')

      item.run
    end

    it "should run failure callback if reject value entered" do
      call_me = i_should_be_called
      call.should_receive(:input).with(3, anything).and_return('123')
      item = form_field(:my_field, :length => 3, :attempts => 1) do
        prompt :play => "first"

        failure { call_me.call }
        confirm(:accept => '1', :reject => '2') { [] }
      end
      call.should_receive(:input).with(1, anything).and_return('2')

      item.run
    end

    it "should play confirmation input prompt if confirm block return value is array" do
      call_me = i_should_be_called
      call.should_receive(:input).with(3, anything).and_return('123')

      item = form_field(:my_field, :length => 3, :attempts => 1) do
        prompt :play => "first"

        success { call_me.call }
        confirm(:timeout => 3) { [] }
      end
      call.should_receive(:input).with(1, {:play => [], :timeout => 3}).and_return('1')

      item.run
    end

    it "should speak confirmation input prompt if confirm block return value is string" do
      call_me = i_should_be_called
      call.should_receive(:input).with(3, anything).and_return('123')

      item = form_field(:my_field, :length => 3, :attempts => 1) do
        prompt :play => "first"

        success { call_me.call }
        confirm(:timeout => 3) { 'speak me' }
      end
      call.should_receive(:input).with(1, {:speak => 'speak me', :timeout => 3}).and_return('1')

      item.run
    end
  end

  it "should run failure callback if no input" do
    call_me = i_should_be_called
    item = form_field(:my_field, :length => 3) do
      prompt :play => "first"
      failure { call_me.call }
    end
    call.should_receive(:input).and_return('')

    item.run
  end

  it "should run success callback if input valid length" do
    call_me = i_should_be_called
    item = form_field(:my_field, :length => 3) do
      prompt :play => "first"
      success { call_me.call }
    end
    call.should_receive(:input).and_return('123')

    item.run
  end

  it "should run success callback if input valid length and valid input" do
    validate_me = i_should_be_called
    call_me = i_should_be_called
    item = form_field(:my_field, :length => 3) do
      prompt :play => "first"
      validate do
        validate_me.call
        my_field.to_i > 100
      end
      success { call_me.call }
    end
    call.should_receive(:input).and_return('123')

    item.run
  end

  it "should execute input with message when bargein is true" do
    item = form_field(:my_field, :length => 3) do
      prompt :play => "first", :bargein => true
    end
    call.should_not_receive(:play)
    call.should_receive(:input).with(3, :play => "first", :timeout => 5)

    item.run
  end

  it "should execute playback method with message and input without message when bargein is false" do
    item = form_field(:my_field, :length => 3) do
      prompt :play => "first", :bargein => false
    end
    call.should_receive(:play).with('first')
    call.should_receive(:input).with(3, :timeout => 5)

    item.run
  end

  def form_field(field, options={}, &block)
    self.class.class_eval { attr_accessor field }
    VoiceForm::FormField.new(field, {:attempts => 3}.merge(options), self, &block)
  end
end

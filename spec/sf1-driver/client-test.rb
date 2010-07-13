require "sf1-driver/client"
require "timeout"

describe Sf1Driver::Client do
  context "when created with mock server" do
    include Sf1DriverMock
    before(:each) do
      @client = Sf1Driver::Client.new(:port => 18283)
    end

    it "is not connected" do
      @client.connected?.should be_false
    end

    it "will connect to 127.0.0.1:18283" do
      @client.host.should == "127.0.0.1"
      @client.port.should == 18283
    end

    it "can successfully connect to server" do
      sf1_mock do
        @client.connect.should_not be_nil
        @client.connected?.should be_true
      end
    end

    it "is refused to connect to not running server" do
      lambda { @client.connect }.should raise_exception(Errno::ECONNREFUSED)
    end

    it "automatically connects when sending" do
      sf1_mock do
        @client.send_request 1, "test"
        @client.connected?.should be_true
      end
    end

    it "gets nothing in response" do
      @client.get_response.should be_nil
    end
  end

  context "when connect to twitter.com in China" do
    it "is timeout" do
      client = Sf1Driver::Client.new(:host => "twitter.com",
                                     :port => 80)
      lambda { Timeout::timeout(1) {client.connect} }.should raise_exception(Timeout::Error)
    end
  end

  context "when has been connected to server" do
    include Sf1DriverMock
    before(:each) do
      @client = Sf1Driver::Client.new(:port => 18283, :timeout => 1)
    end
  
    it "is not connected after close" do
      sf1_mock do
        @client.connect
        @client.close
        @client.connected?.should be_false
      end
    end

    it "cannot gets response without sending request" do
      sf1_mock do
        @client.connect
        lambda { Timeout::timeout(1) {@client.get_response} }.should raise_exception(Timeout::Error)
      end
    end

    it "sends request to server successfully" do
      sequence = 1
      request = "abc"

      handler_mock = mock("handler_mock")
      handler_mock.should_receive(:on_request).once.with(sequence, request)

      sf1_mock(handler_mock) do
        @client.connect
        @client.send_request(sequence, request)
        @client.get_response
      end
    end

    it "can get response after sending request" do
      sequence = 1
      request = "abc"
      response = "def"

      handler_mock = mock("handler_mock")
      handler_mock.should_receive(:on_request).once.with(sequence, request).
        and_return(response)

      sf1_mock(handler_mock) do
        @client.connect
        @client.send_request(sequence, request)
        actual_sequence, actual_response = @client.get_response
        actual_sequence.should == sequence
        actual_response.should == response
      end
    end

    it "is timeout if the server is shutdown while getting response" do
      handler_mock = mock("handler_mock")
      handler_mock.should_receive(:on_request).once.
        and_throw(:done)

      sf1_mock(handler_mock) do
        @client.connect
        @client.send_request(1, "test")
        lambda{Timeout.timeout(1){@client.get_response}}.
          should raise_exception(Timeout::Error)
      end
    end

    it "gets response using call" do
      sequence = 1
      request = "abc"
      response = "def"

      handler_mock = mock("handler_mock")
      handler_mock.should_receive(:on_request).once.with(sequence, request).
        and_return(response)

      sf1_mock(handler_mock) do
        @client.connect
        actual_sequence, actual_response = @client.call(sequence, request)
        actual_sequence.should == sequence
        actual_response.should == response
      end
    end
  end
end

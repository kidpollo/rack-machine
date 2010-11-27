require 'spec_helper'

class TestServer
  include RackMachine::Server
end

describe TestServer, "#receive_data" do
  
  before(:all) do
    @test_server = TestServer.new
  end
  
  it "should call the send a response when receiving data" do
    @test_server.should_receive(:send_data)
    @test_server.receive_data 'command'
  end
  
  context 'authentication' do 
    
    before(:all) do
      @test_server.should_receive(:send_data)
    end
    
    it 'should try to authenticate' do
      @test_server.receive_data 'login'
    end
    
  end
  
end
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "AwisWrapper" do
  
  context "with all correct configuration" do
    
    let(:url_info) { IO.read(Pathname.new(File.expand_path(File.dirname(__FILE__))).join("fixtures", "url_info.xml")) }
  
    let(:bad_request) { IO.read(Pathname.new(File.expand_path(File.dirname(__FILE__))).join("fixtures", "bad_request.xml")) }
  
    let(:wrong_response) { IO.read(Pathname.new(File.expand_path(File.dirname(__FILE__))).join("fixtures", "wrong_response.xml")) }
    
    before(:each) do
      Amazon::Awis.options = {:aws_access_key_id => "test_123", :aws_secret_key => "test_456"}
    end

    it "would return the correct url" do
      Amazon::Awis.options[:action] = 'UrlInfo'
      Amazon::Awis.options[:responsegroup] = 'UsageStats'
      FakeWeb.register_uri(:get, %r{https://#{Amazon::Awis::AWIS_DOMAIN}/?.*}, body: url_info)
      response = Amazon::Awis.get_info("yahoo.com")
      response.doc.should_not be_nil
      response.success?.should == true
      response.get_all("country").size.should == 34
    end
  
    it "return bad url with the wrong action" do
      Amazon::Awis.options[:action] = 'wrong_action123'
      Amazon::Awis.options[:responsegroup] = 'RankByCountry'
      FakeWeb.register_uri(:get, %r{https://#{Amazon::Awis::AWIS_DOMAIN}/?.*}, body: bad_request, :status => ["400", "Bad Request"])
      expect { Amazon::Awis::get_info("yahoo.com") }.to raise_error(Amazon::RequestError)
    end
  
    it "return error code with wrong response group" do
      Amazon::Awis.options[:action] = 'UrlInfo'
      Amazon::Awis.options[:responsegroup] = 'RankByzzzzzCsountry' # made one typo for this example
      FakeWeb.register_uri(:get, %r{https://#{Amazon::Awis::AWIS_DOMAIN}/?.*}, body: wrong_response)
      response = Amazon::Awis.get_info('yahoo.com')
      response.success?.should == false
      response.error.should == "The following response groups are invalid: RankByCsountry"
    end
  
    
  end
  
  context "with missing configuration" do
    
    let(:wrong_request) { IO.read(Pathname.new(File.expand_path(File.dirname(__FILE__))).join('fixtures', 'wrong_request.xml')) }
    
    it "would arise error" do
      FakeWeb.register_uri(:get, %r{https://#{Amazon::Awis::AWIS_DOMAIN}/?.*}, body: wrong_request, :status => ["403", "Forbidden"])
      expect { Amazon::Awis::get_info("yahoo.com") }.to raise_error(Amazon::RequestError)
    end
  end
  
  context "with batch query" do
    
    let(:batch_request) { IO.read(Pathname.new(File.expand_path(File.dirname(__FILE__))).join('fixtures', 'batch_info.xml')) }
    it "return multiple datasets" do
      FakeWeb.register_uri(:get, %r{https://#{Amazon::Awis::AWIS_DOMAIN}/?.*}, body: batch_request)
      responses = Amazon::Awis::get_batch_info(['yahoo.com', 'cnn.com'])
      responses.get_all('response').size.should == 2
      responses.get_all('response')[0].get_all_child('country').size.should == 34
      responses.get_all('response')[1].url_info_result.first.alexa.should_not be_empty
    end
  end
  
end

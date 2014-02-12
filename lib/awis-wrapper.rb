#--
# Copyright (c) 2013 vincent zhu
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require "cgi"
require "base64"
require "openssl"
require "digest/sha1"
require "uri"
require "net/https"
require "time"
require "nokogiri"
require "extlib"

module Amazon
  
  class RequestError < StandardError; end
  
  class Awis
        
    NAMESPACE = {:aws => "http://awis.amazonaws.com/doc/2005-07-11"}
    AWIS_DOMAIN = 'awis.amazonaws.com'
    
    @@options = {
    	    :action => "UrlInfo",
    	    :responsegroup => "Rank"
    }
    
    @@debug = false

    # Default service options
    def self.options
    	    @@options
    end
    
    # Set default service options
    def self.options=(opts)
    	    @@options = opts
    end
    
    # Get debug flag.
    def self.debug
    	    @@debug
    end
    
    # Set debug flag to true or false.
    def self.debug=(dbg)
    	    @@debug = dbg
    end
    
    def self.configure(&proc)
    	    raise ArgumentError, "Block is required." unless block_given?
    	    yield @@options
    end
    
    def self.get_info(domain)    
    	    url = self.prepare_url(domain)
    	    log "Request URL: #{url}"
    	    res = Net::HTTP.get_response(url)
    	    unless res.kind_of? Net::HTTPSuccess
    	    	    raise Amazon::RequestError, "HTTP Response: #{res.code} #{res.message} #{res.body}"
    	    end
    	    log "Response text: #{res.body}"
    	    Response.new(res.body)
    end	 
    
    def self.get_batch_info(domains)
	    url = self.batch_urls(domains)
      log "Request URL: #{url}"
	    res = Net::HTTP.get_response(url)
	    unless res.kind_of? Net::HTTPSuccess
	    	    raise Amazon::RequestError, "HTTP Response: #{res.code} #{res.message} #{res.body}"
	    end
      log "Response text: #{res.body}"
	    Response.new(res.body)
    end
       
	        
    # Response object returned after a REST call to Amazon service.
    class Response
      # XML input is in string format
      def initialize(xml)
	      @doc = Nokogiri::XML(xml)
        @namespace = Awis::NAMESPACE
      end

      def doc
        @doc
      end      
      
      def xpath(path)
        @doc.xpath(path, @namesapce)
      end
      
      def get(tag)
        Element.new @doc.at_xpath("//aws:#{tag.camel_case}", @namespace)
      end
      
      def get_all(tag)
        @doc.xpath("//aws:#{tag.camel_case}", @namespace).collect{|data|Element.new data}
      end
      
      # Return error code
      def error
        @doc.at_xpath("//aws:StatusMessage").content
      end
      
      # Return error message.
      def success?
      	(@doc.at_xpath "//aws:StatusCode").content == "Success"     	      	      
      end
      
      #returns inner html of any tag in awis response i.e resp.rank => 3
      def method_missing(methodId)
        puts methodId
        @doc.send methodId 
      end	                  
            
    end
    
    class Element
      def initialize(arg)
        @node = arg
      end
      
      def [](key)
        @node[key.to_s]
      end
      
      def get_all_child(str)
        result = @node.xpath(".//aws:#{str.to_s.camel_case}", Awis::NAMESPACE)
        if result 
            result.collect do |r|
              Element.new r
            end
        else
          result
        end
      end
      
      def method_missing(methodId)
        result = @node.xpath("./aws:#{methodId.to_s.camel_case}", Awis::NAMESPACE)
        if result 
            result.collect do |r|
              Element.new r
            end
        else
          result
        end
      end
      
      def to_s
        @node.content
      end
      
      
    end
    
    protected
    
    def self.log(s)
    	    return unless self.debug
    	    if defined? RAILS_DEFAULT_LOGGER
    	    	    RAILS_DEFAULT_LOGGER.error(s)
    	    elsif defined? LOGGER
    	    	    LOGGER.error(s)
    	    else
    	    	    puts s
    	    end
    end
      
    private 
    
    # Converts a hash into a query string (e.g. {a => 1, b => 2} becomes "a=1&b=2")
    def self.escape_query(query)
      query.sort.map{|k,v| k + "=" + URI.escape(v.to_s, /[^A-Za-z0-9\-_.~]/)}.join('&')
    end
    
    def self.prepare_url(domain)
      query = {
        'AWSAccessKeyId'   => self.options[:aws_access_key_id],
        'Action'           => self.options[:action],
        'ResponseGroup'    => self.options[:responsegroup],
        'SignatureMethod'  => 'HmacSHA1',
        'SignatureVersion' => 2,
        'Timestamp'        => Time.now.utc.iso8601,
        'Url'              => domain
      }
      awis_domain = Amazon::Awis::AWIS_DOMAIN
      URI.parse("http://#{awis_domain}/?" + escape_query(query.merge({ 
        'Signature' => Base64.encode64(
          OpenSSL::HMAC.digest(
            'sha1', self.options[:aws_secret_key], 
            "GET\n#{awis_domain}\n/\n" + escape_query(query).strip)).chomp
      })))
    end
    
    def self.batch_urls(urls)
      raise Amazon::RequestError, "Awis batch request cannot be > 5" unless urls.length < 6

      # timestamp = ( Time::now ).utc.strftime("%Y-%m-%dT%H:%M:%S.000Z")
      awis_domain = Amazon::Awis::AWIS_DOMAIN  

      batch_query = {
        "Action"                          => self.options[:action],
        "AWSAccessKeyId"                  => self.options[:aws_access_key_id],
        "Timestamp"                       => Time.now.utc.iso8601,
        "#{self.options[:action]}.Shared.ResponseGroup"  => self.options[:responsegroup],
        "SignatureVersion"                => 2,
        "SignatureMethod"                 => "HmacSHA1"
      }
  
      urls.each_with_index do |url,i|
        batch_query["#{self.options[:action]}.#{i+1}.Url"] = url
      end
      signature = Base64.encode64( OpenSSL::HMAC.digest( OpenSSL::Digest.new( "sha1" ), 
        self.options[:aws_secret_key], "GET\n#{awis_domain}\n/\n" + escape_query(batch_query))).strip
      query_str = batch_query.merge({'Signature' => signature})
      url = "http://#{awis_domain}/?#{escape_query(query_str)}"
      URI.parse url
  end
    
  end

  

end

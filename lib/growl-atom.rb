require 'rubygems'
require 'growl'
require 'yaml'
require 'digest/md5'
require 'uri'
require 'net/http'
require 'net/https'
require 'rexml/document'

module GrowlAtom

	VERSION = "0.0.1"
	
	class Error < StandardError; end

	# The Installation directory of this gem package	
	def GrowlAtom.gem_dir 
		File.expand_path(File.join(File.dirname(__FILE__), '..'))
	end
	
	# Check all URLs in this config file
	def GrowlAtom.check(config_dir)
		
		default_options = {
			:name => 'growl-atom',
			:title => 'title',
			:message => 'summary',
			:growl_host => 'localhost',
			:sticky => true
		}
		
		config = YAML.load_file(File.join(config_dir, 'config'))
		cache_dir = File.join(config_dir, 'caches')
				
		config['feeds'].each {|feed|
			options = default_options.merge(config['global']).merge(feed)
			self.parse_feed(self.get_feed(options), options, cache_dir)
		}

	end
	
	# Download feed respecting any http proxy, auth type stuff set in options
	def GrowlAtom.get_feed(options)
	
		raise Error, "No url set for feed" unless options['url'] != nil
		
		uri = URI.parse(options['url'])

		http = Net::HTTP.new(uri.host, uri.port)

		req = Net::HTTP::Get.new(uri.path)

		if (uri.scheme == 'https')
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		end
		
		if (options['auth_user'] && options['auth_pass'])
			req.basic_auth options['auth_user'], options['auth_pass']
		end
		
		response = http.request(req)
		
		if (!response.kind_of?(Net::HTTPClientError) && !response.kind_of?(Net::HTTPServerError))
			return response.body
		end
		
		raise Error, "#{response.code} Error in HTTP Response for #{options['url']}"
		
	end
	
	# Parse feed xml
	def GrowlAtom.parse_feed(feed_xml, options, cache_dir)
		
		cache_file = File.join(cache_dir, Digest::MD5.hexdigest(options['url']))
		system("touch #{cache_file}")
		
		include REXML
		
		doc = Document.new feed_xml
		doc.elements.each('//entry') {|entry| 
			
			id = entry.elements['id'].text			
			
			if (!system("grep #{id} #{cache_file} > /dev/null")) 
		
				growl_options = {}
				
				growl_options['name'] = options['name']
				growl_options['host'] = options['growl_host']
				growl_options['sticky'] = options['sticky']
				growl_options['title'] = entry.elements[options['title']].text
				growl_options['message'] = entry.elements[options['message']].text				
				
				growl_options['password'] = options['growl_pass'] unless(options['growl_pass'] == nil)
				growl_options['image'] = File.expand_path(options['image']) unless(options['image'] == nil)
								
				Growl.notify(growl_options['message'], growl_options)
				
			 	system("echo #{id} >> #{cache_file}")
			
			end
		
		}						
	end	
			
end
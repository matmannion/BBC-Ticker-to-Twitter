#!/usr/bin/ruby1.9.1
# encoding: utf-8

require 'json'
require 'net/http'
require 'twitter'
require 'bitly'
require 'yaml'
require 'htmlentities'

def get_news(url, filename, include_prompt=false)
	db = from_file(filename)
	
	oauth = Twitter::OAuth.new(db['consumer_key'],db['consumer_secret'])
	oauth.authorize_from_access(db['access_token'], db['access_secret'])

	client = Twitter::Base.new(oauth)

	bitly = Bitly.new(db['bitly_user'],db['bitly_apikey'])

	coder = HTMLEntities.new

	resp = Net::HTTP.get_response(URI.parse(url))
	JSON.parse(resp.body)['entries'].each {|entry|
		if not entry['url'].nil? and not entry['url'].empty?
			longurl = entry['url']

			if longurl.match(/^\/news\//) || longurl.match(/^\/sport\//)
				longurl = "http://www.bbc.co.uk#{longurl}"
			end

			if not longurl.match(/^http/)
				longurl = "http://news.bbc.co.uk#{longurl}"
			end

			if longurl.match(/^http:\/\/.co.uk\//)
				longurl = "http://bbc.co.uk#{longurl[13..-1]}"
			end

			if not db.has_key?(longurl)
				begin
					url = bitly.shorten(longurl).short_url
				rescue
					url = longurl
				end

				maxlength = 138 - url.length
				tweet = "#{entry['headline']}"
				if include_prompt
					tweet = "#{entry['prompt'].capitalize}: #{tweet}"
				end

				if tweet.length > maxlength
					tweet = tweet[0..maxlength-3] + "..."	
				end

				tweet = "#{tweet} #{url}"

				tweet = coder.decode(tweet.force_encoding('iso-8859-1').encode('us-ascii', :undef => :replace, :replace => ''))
				db[longurl] = tweet
				begin
					client.update(tweet)
				rescue
					puts 'couldnt post tweet'
				end
			end
		end
	}

	to_file(db, filename)
end

def from_file(filename)
	if File.exists?(filename)
		YAML::load(File.open(filename, 'r'))
	else
		{}
	end
end

def to_file(map, filename)
	File.open(filename, 'w') do |file|
		file.puts map.to_yaml
	end
end

get_news('http://www.bbc.co.uk/news/10284448/ticker.sjson', '/home/mat/pkgs/bbcbreaking/news.yaml', false)
get_news('http://news.bbc.co.uk/sol/ukfs_sport/hi/front_page/ticker.json','/home/mat/pkgs/bbcbreaking/sports.yaml', true)

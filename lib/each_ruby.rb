require "each_ruby/version"
require 'faraday'
require 'faraday_middleware'
require 'json'
require 'uri'

module EachRuby
  BASE_URL = 'http://melpon.org'
  def self.run(fname)
    conn = Faraday.new BASE_URL do |c|
      c.use FaradayMiddleware::FollowRedirects
      c.response :logger if ENV['DEBUG_EACH_RUBY']
      c.adapter :net_http
    end
    resp = conn.get '/wandbox/api/list.json'
    body = JSON.parse(resp.body)
    rubies = body.select do |c|
      c['display-name'] == 'ruby'
    end.group_by do |c|
      c['version'][0..2]
    end.map do |_, cs|
      cs.sort_by {|c| Gem::Version.new(c['version']) }.last
    end

    code = File.read(fname)

    rubies.each do |ruby|
      resp = conn.post do |req|
        req.url '/wandbox/api/compile.json'
        req.headers['Content-Type'] = 'application/json'
        req.body = JSON.generate(
          compiler: ruby['name'],
          code: code,
          options: '-v'
        )
      end
      body = JSON.parse(resp.body)
      puts "$ #{ruby['name']} #{fname}"
      print body['program_output']
      print body['program_error']
    end
  end
end

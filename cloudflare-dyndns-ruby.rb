#!/usr/bin/env ruby

require 'net/http'
require 'json'

class Cloudflare
  def initialize(email, key)
    @email = email
    @key = key
  end

  def get(path, query = {})
    uri = URI.parse(build_url(path, query))
    request = Net::HTTP::Get.new(uri)
    perform(uri, request)
  end

  def put(path, data)
    uri = URI.parse(build_url(path))
    request = Net::HTTP::Put.new(uri)
    request.body = data.to_json
    perform(uri, request)
  end

  private
  def build_url(path, query_string = {})
    "https://api.cloudflare.com/client/v4#{path}?#{URI.encode_www_form(query_string)}"
  end

  def perform(uri, request)
    request["X-Auth-Email"] = @email
    request["X-Auth-Key"] = @key
    request["Content-Type"] = "application/json"

    Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == 'https')) do |http|
      handle_response http.request(request)
    end
  end

  def handle_response(response)
    data = parse_json(response.body)
    case response
    when Net::HTTPSuccess
      data.fetch("result")
    else
      raise data.fetch("errors").map { |error|
        "ERROR #{error["code"]}: #{error["message"]}"
      }.join("\n")
    end
  end

  def parse_json(body)
    JSON.parse(body)
  rescue => error
    STDERR.puts "Could not parse JSON response: #{error}"
    STDERR.puts body
    exit 1
  end
end

class VerboseCloudflare
  def initialize(cloudflare)
    @cloudflare = cloudflare
  end

  def get(path, query = {})
    STDERR.puts "> GET #{path} #{query.to_json}"
    verbose_response @cloudflare.get(path, query)
  end

  def put(path, data)
    STDERR.puts "> PUT #{path}"
    STDERR.puts "> #{data.to_json}"
    verbose_response @cloudflare.put(path, data)
  end

  private
  def verbose_response(response)
    JSON.pretty_generate(response).split("\n").each do |line|
      STDERR.puts "> #{line}"
    end
    response
  end
end

class DnsUpdater
  def initialize(cloudflare, zone_name, record_name)
    @cloudflare = cloudflare
    @zone_name = zone_name
    @record_name = record_name
  end

  def update_dns_record(new_ip)
    @cloudflare.put("/zones/#{zone_id}/dns_records/#{dns_id}", dns_record.merge(content: new_ip))
  end

  private
  attr_reader :zone_name, :record_name

  def fetch_zone_id
    response = @cloudflare.get("/zones", name: zone_name)
    zone = response.first
    raise "Could not find zone with name #{zone_name}" unless zone
    zone.fetch("id")
  end

  def zone_id
    @zone_id ||= fetch_zone_id
  end

  def fetch_dns_record
    response = @cloudflare.get("/zones/#{zone_id}/dns_records", name: record_name, type: "A")
    record = response.first
    raise "Could not find \"A\" DNS record with name #{record_name}" unless record
    record
  end

  def dns_record
    @dns_record ||= fetch_dns_record
  end

  def dns_id
    dns_record.fetch("id")
  end
end

def main(verbose: false)
  email      = ENV.fetch("CLOUDFLARE_API_EMAIL")
  key        = ENV.fetch("CLOUDFLARE_API_KEY")
  zone_name  = ENV.fetch("CLOUDFLARE_ZONE_NAME")
  dns_record = ENV.fetch("CLOUDFLARE_DNS_RECORD")

  cloudflare = Cloudflare.new(email, key)
  cloudflare = VerboseCloudflare.new(cloudflare) if verbose

  updater = DnsUpdater.new(cloudflare, zone_name, dns_record)

  ip = determine_ip(verbose: verbose)
  STDERR.print "Updating... " unless verbose
  updater.update_dns_record(ip)
  STDERR.puts "OK" unless verbose
  STDOUT.puts ip
end

IP_URIS = [
  URI.parse("https://ipof.in/txt"),
  URI.parse("https://4.ifcfg.me/i"),
  URI.parse("http://whatismyip.akamai.com/"),
].freeze

def determine_ip(verbose:)
  IP_URIS.each do |uri|
    STDERR.puts "> GET #{uri}" if verbose
    ip = Net::HTTP.get(uri).strip
    if ip =~ /\d{1,3}(\.\d{1,3}){3}/
      return ip
    else
      STDERR.puts "ERROR: Not a valid IP: #{ip}"
    end
  end
  STDERR.puts "ERROR: Could not determine IP!"
  exit 1
end

if ARGV.include?("--help")
  puts <<-USAGE
#$0 [-v] [--help[

Determines the machine's current external IP, then updates a specific DNS A record on Cloudflare with that IP.

OPTIONS:
  -v        Verbose. Show all HTTP requests and responses.

  --help    Show this help.

ENVIRONMENT VARIABLES:
  CLOUDFLARE_API_EMAIL     (Required) Email address of Cloudflare account.

  CLOUDFLARE_API_KEY       (Required) API key of Cloudflare account.

  CLOUDFLARE_ZONE_NAME     (Required) The name of your zone, for example "example.com".

  CLOUDFLARE_DNS_RECORD    (Required) The DNS record name, for example "example.com"
                           or "subdomain.example.com". Must be an A record.
  USAGE
  exit 0
end

main(verbose: ARGV.include?("-v"))

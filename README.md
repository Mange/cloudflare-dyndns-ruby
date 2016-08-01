# cloudflare-dyndns-ruby

> A small Ruby script that updates a Cloudflare DNS entry with the machine's current external IP.

## What it does

It contacts some external service that returns your current IP, then connects to the Cloudflare API and updates a DNS record with that IP. Use it for "dyndns"-like ("dynamic DNS") uses, such as your personal machine or a VPS without a fixed IP.

Services used (in order):
  * https://ipof.in/txt
  * https://4.ifcfg.me/i
  * http://whatismyip.akamai.com/

If any of them don't respond with just an IP, it will be skipped and the next one will be tried.

## Dependencies and installation

It's written to require no dependencies other than Ruby itself. `apt-get install ruby` should suffice for any Debian-based distro, as long as Ruby is >= 1.9.3.

It's also written in a single file so you can copy it to a server and then run it immediately.

## Security

**This is not very secure.** If any of the IP services are compromised, your entry might be updated to the wrong IP, leading to a full takeover of your site. **Never use this for any critical service or service with actual users!**

I recommend that you only use this for HTTP traffic when you have an SSL cert already on your machine and can lock it with Cloudflare so no traffic will be sent to an unexpected IP.

## Usage

```
cloudflare-dyndns-ruby.rb [-v] [--help]

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
```

## License

This code is released under a MIT license.

Copyright © 2016 Magnus Bergmark.

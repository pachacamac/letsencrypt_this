#!/usr/bin/env ruby

require 'acme-client'
require 'openssl'
require 'uri'
require 'net/http'
# require 'byebug'

opts = Hash[ARGV.each_slice(2).to_a]

if opts['-h'] || !opts['-d']
  puts 'options:'
  puts "-d domain"
  puts "-m mode       (optional. test or live. default is live)"
  puts "-e email      (optional. default is info@<domain>)"
  puts "-k key        (optional. path to private key)"
  puts "-c challenge  (optional. path to stored challenge file)"
  exit
end

endpoint = if ['test', 'staging'].include?(opts['-m'])
             puts 'test/staging mode'
             'https://acme-staging.api.letsencrypt.org/'
           else
             puts 'live mode'
             'https://acme-v01.api.letsencrypt.org/'
           end

domain = opts['-d']
raise 'specify domain via -d option' unless domain

email = opts['-e'] || "info@#{domain}"

base_dir = File.expand_path("./#{domain}")
FileUtils.mkdir_p(base_dir)

stored_challange = opts['-c'] || File.join(base_dir, './letsencrypt_challenge.json')

key_file = opts['-k'] || File.join(base_dir, './id_rsa')

priv_key = if File.exist?(key_file)
             puts 'using existing private key'
             OpenSSL::PKey::RSA.new(IO.read(File.expand_path(key_file)))
           else
             puts 'creating new private key'
             OpenSSL::PKey::RSA.new(4096).tap do |key|
               File.write(File.join(base_dir, './id_rsa'), key.to_s)
               File.write(File.join(base_dir, './id_rsa.pub'), key.public_key.to_s)
             end
           end

########################################################################################################################
# Patch some shit
class Acme::Client::Crypto
  def generate_signed_jws(header:, payload:)
    jwt = JSON::JWT.new(payload || {})
    jwt.header.merge!(header || {})
    jwt.header[:jwk] = jwk
    jws = jwt.sign(private_key, :RS256)
    jws.to_json(syntax: :flattened)
  end
end

########################################################################################################################
# Create client, register it if it hasn't been registered yet
client = Acme::Client.new(private_key: priv_key,
                          endpoint: endpoint,
                          connection_options: { request: { open_timeout: 10, timeout: 10 } })
begin
  print 'Trying to register client.'
  registration = client.register(contact: "mailto:#{email}")
  registration.agree_terms
  puts 'done.'
rescue Acme::Client::Error::Malformed
  puts 'already registered.'
end
########################################################################################################################
# Prove that you're the owner of said domain(s)

authorization = client.authorize(domain: domain)

if stored_challange && File.exist?(stored_challange)
  puts 'using existing challenge'
  challenge = client.challenge_from_hash(JSON.parse(File.read(stored_challange)))
else
  puts 'creating challenge'
  challenge = authorization.http01
  challenge_dir = File.join(base_dir, File.dirname(challenge.filename))
  challenge_file = File.basename(challenge.filename)
  FileUtils.mkdir_p(challenge_dir)
  File.write(File.join(challenge_dir, challenge_file), challenge.file_content)
  File.write((stored_challange || 'letsencrypt_challenge.json'), challenge.to_h.to_json)
  puts "challenge created in: #{File.join(base_dir, challenge.filename)}"
  puts
end

puts "challenge content is:  #{challenge.file_content}"
puts "make it accessible at: #{domain}/#{challenge.filename}"
puts
print 'checking from local '

loop do
  response = `curl -sL '#{domain}/#{challenge.filename}'` # TODO: exchange with pure ruby solution
  result = response.strip == challenge.file_content.strip
  if result
    puts 'FOUND!'
    break
  end
  print '.'
  sleep 5
end

puts 'attempting letsencrypt challenge verification ...'
challenge.request_verification
print 'waiting for challenge verification '
loop do
  if challenge.verify_status != 'pending'
    puts 'VERIFIED!'
    break
  end
  sleep 2
  print '.'
end
raise "Challenge could not be verified: #{challenge.verify_status}." if challenge.verify_status != 'valid'

########################################################################################################################
# Create certificate files for your domain(s)

csr = Acme::Client::CertificateRequest.new(names: [domain])
certificate = client.new_certificate(csr)

def dhparam(opts = {})
  opts[:bits] ||= 4096
  if opts[:generate]
    puts 'generating dhparam. this may take a while.'
    OpenSSL::PKey::DH.new(opts[:bits]).to_s
  else
    puts 'using precomputed dhparam. has nobody got time to wait.'
    Net::HTTP.get(URI("https://2ton.com.au/dhparam/#{opts[:bits]}/#{rand(0..127)}"))
  end
end

puts 'writing pem files.'

# Save the certificate and the private key to files
File.write(File.join(base_dir, 'privkey.pem'), certificate.request.private_key.to_pem)
File.write(File.join(base_dir, 'cert.pem'), certificate.to_pem)
File.write(File.join(base_dir, 'chain.pem'), certificate.chain_to_pem)
File.write(File.join(base_dir, 'fullchain.pem'), certificate.fullchain_to_pem)
File.write(File.join(base_dir, 'dhparam.pem'), dhparam(bits: 4096, generate: false)) # TODO: make parameterized

puts 'all done!'

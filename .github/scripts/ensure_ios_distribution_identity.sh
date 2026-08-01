#!/usr/bin/env bash
# Ensure an Apple Distribution codesigning identity exists in the login keychain.
#
# When APPLE_USE_RUNNER_KEYCHAIN=true and only Developer ID / Apple Development are
# present, create a fresh IOS_DISTRIBUTION certificate via App Store Connect API
# (revoking orphan portal certs we cannot use), then import it.
#
# Requires:
#   APP_STORE_CONNECT_API_KEY_ID
#   APP_STORE_CONNECT_ISSUER_ID
#   APP_STORE_CONNECT_API_PRIVATE_KEY
set -euo pipefail

lib="$(dirname "$0")/release_lib.sh"
# shellcheck source=release_lib.sh
source "${lib}"

has_distribution_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Distribution/ { found=1 } END { exit found ? 0 : 1 }'
}

if has_distribution_identity; then
  echo "Apple Distribution identity already present."
  security find-identity -v -p codesigning | awk '/Apple Distribution/ { print }'
  exit 0
fi

for var in APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_API_PRIVATE_KEY; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing ${var}; cannot create Apple Distribution certificate via API." >&2
    exit 1
  fi
done

# Persist identifiers early for local debugging if the API call fails later.
ASC_CACHE_DIR="${HOME}/.config/enjoy-player"
mkdir -p "${ASC_CACHE_DIR}"
umask 077
cat >"${ASC_CACHE_DIR}/asc.env" <<EOF
APP_STORE_CONNECT_API_KEY_ID=${APP_STORE_CONNECT_API_KEY_ID}
APP_STORE_CONNECT_ISSUER_ID=${APP_STORE_CONNECT_ISSUER_ID}
EOF
chmod 600 "${ASC_CACHE_DIR}/asc.env"

WORKDIR="${RUNNER_TEMP:-/tmp}/enjoy-ios-distribution-$$"
mkdir -p "${WORKDIR}"
chmod 700 "${WORKDIR}"
cleanup() {
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

KEY_PATH="${WORKDIR}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
release_write_asc_api_private_key "${KEY_PATH}"

CSR_KEY="${WORKDIR}/ios_distribution.key"
CSR_PATH="${WORKDIR}/ios_distribution.csr"
CERT_PATH="${WORKDIR}/ios_distribution.cer"
P12_PATH="${WORKDIR}/ios_distribution.p12"
P12_PASSWORD="$(openssl rand -base64 24)"

openssl req -new -newkey rsa:2048 -nodes \
  -keyout "${CSR_KEY}" \
  -out "${CSR_PATH}" \
  -subj "/emailAddress=ci@enjoy.bot/CN=Enjoy Player CI/C=US" >/dev/null 2>&1

echo "Creating Apple Distribution certificate via App Store Connect API..."

ruby --disable-gems - "${KEY_PATH}" "${APP_STORE_CONNECT_API_KEY_ID}" \
  "${APP_STORE_CONNECT_ISSUER_ID}" "${CSR_PATH}" "${CERT_PATH}" <<'RUBY'
require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

p8_path, key_id, issuer_id, csr_path, cert_path = ARGV

def b64url(data)
  Base64.urlsafe_encode64(data).delete("=")
end

def asc_token(p8_path, key_id, issuer_id)
  key = OpenSSL::PKey.read(File.read(p8_path))
  header = b64url({ alg: "ES256", kid: key_id, typ: "JWT" }.to_json)
  now = Time.now.to_i
  payload = b64url({
    iss: issuer_id,
    iat: now,
    exp: now + 20 * 60,
    aud: "appstoreconnect-v1",
  }.to_json)
  signing_input = "#{header}.#{payload}"
  # OpenSSL ECDSA signatures are DER-encoded; JWT needs raw r||s (32+32).
  der = key.sign(OpenSSL::Digest::SHA256.new, signing_input)
  asn1 = OpenSSL::ASN1.decode(der)
  r = asn1.value[0].value.to_s(2)
  s = asn1.value[1].value.to_s(2)
  r = r.rjust(32, "\x00")[-32, 32]
  s = s.rjust(32, "\x00")[-32, 32]
  "#{signing_input}.#{b64url(r + s)}"
end

def asc_request(method, path, token, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = case method
        when :get then Net::HTTP::Get.new(uri)
        when :post then Net::HTTP::Post.new(uri)
        when :delete then Net::HTTP::Delete.new(uri)
        else
          raise "unsupported method #{method}"
        end
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body
  res = http.request(req)
  parsed = res.body.nil? || res.body.empty? ? nil : JSON.parse(res.body)
  [res.code.to_i, parsed]
end

token = asc_token(p8_path, key_id, issuer_id)

# Revoke portal IOS_DISTRIBUTION certs we cannot sign with (no local private key).
code, listed = asc_request(
  :get,
  "/v1/certificates?filter[certificateType]=IOS_DISTRIBUTION&limit=200",
  token,
)
raise "list certificates failed (#{code}): #{listed}" unless code == 200

(listed["data"] || []).each do |cert|
  cert_id = cert["id"]
  warn "Revoking orphaned IOS_DISTRIBUTION certificate #{cert_id} (no local private key)"
  del_code, del_body = asc_request(:delete, "/v1/certificates/#{cert_id}", token)
  unless [200, 204].include?(del_code)
    raise "revoke #{cert_id} failed (#{del_code}): #{del_body}"
  end
end

csr = File.read(csr_path)
code, created = asc_request(
  :post,
  "/v1/certificates",
  token,
  {
    data: {
      type: "certificates",
      attributes: {
        certificateType: "IOS_DISTRIBUTION",
        csrContent: csr,
      },
    },
  },
)
raise "create certificate failed (#{code}): #{created}" unless code == 201

content = created.dig("data", "attributes", "certificateContent")
raise "create certificate response missing certificateContent: #{created}" if content.nil? || content.empty?

File.binwrite(cert_path, Base64.decode64(content))
puts "Created IOS_DISTRIBUTION certificate #{created.dig('data', 'id')}"
RUBY

openssl x509 -inform DER -in "${CERT_PATH}" -out "${WORKDIR}/ios_distribution.pem"
openssl pkcs12 -export \
  -inkey "${CSR_KEY}" \
  -in "${WORKDIR}/ios_distribution.pem" \
  -out "${P12_PATH}" \
  -passout "pass:${P12_PASSWORD}" \
  -name "Apple Distribution"

KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
if [[ ! -f "${KEYCHAIN}" ]]; then
  KEYCHAIN="login.keychain"
fi

security import "${P12_PATH}" -k "${KEYCHAIN}" -P "${P12_PASSWORD}" \
  -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/xcrun

# Allow codesign to use the key without GUI prompts on the self-hosted runner.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "${KEYCHAIN}" >/dev/null 2>&1 || true

if ! has_distribution_identity; then
  echo "Apple Distribution identity still missing after import." >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

echo "Apple Distribution identity ready:"
security find-identity -v -p codesigning | awk '/Apple Distribution/ { print }'

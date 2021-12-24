import base64, sys, requests, json

from kubernetes import client, config


base_url = "https://authentik.maibaloc.com/api/v3"

# Init kubernetes client
config.load_kube_config(config_file='../../../metal/kubeconfig.yaml')
v1 = client.CoreV1Api()

# Get authentik secret
def decode(encoded_secret: str) -> str:
    return (base64.b64decode(encoded_secret)).decode()

ak_secrets = v1.read_namespaced_secret("authentik-aka-secret", "platform").data

ak_admin_token = decode(ak_secrets['ak_admin_token'])

gitea_oauth2_client_id = decode(ak_secrets['ak_gitea_oauth2_client_id'])

gitea_oauth2_client_secret = decode(ak_secrets['ak_gitea_oauth2_client_secret'])

# Get the default-provider-authorization-explicit-consent flow from /flows/bindings/
flow_binding_api_url =f"{base_url}/flows/bindings"
res = requests.get(flow_binding_api_url,headers={'Authorization': f"Bearer {ak_admin_token}"})
resp_json = res.json()
target_auth_flow = [
    flow for flow in resp_json["results"] if flow["stage_obj"]["name"] == "default-provider-authorization-consent"
]

# Get rsa_key id via /crypto/certificatekeypairs
crypto_cert_api_url = f"{base_url}/crypto/certificatekeypairs"
res = requests.get(crypto_cert_api_url,headers={'Authorization': f"Bearer {ak_admin_token}"})
resp_json = res.json()
self_signed_cert_id = [
    cert for cert in resp_json["results"] if cert["name"] == "authentik Self-signed Certificate"
]


# Get default OpenID/OAuth2 property mappings /propertymappings/all/ [email, openid, profile] 
prop_mapping_api_url = f"{base_url}/propertymappings/all"
res = requests.get(prop_mapping_api_url,headers={'Authorization': f"Bearer {ak_admin_token}"})
resp_json = res.json()
props_mapping = [
    prop["pk"] for prop in resp_json["results"] if "authentik default OAuth Mapping: OpenID" in prop["name"] 
]

payload = {
    'name': "gitea",
    'authorization_flow': target_auth_flow[0]["target"],
    'property_mappings': props_mapping,
    'client_type':  "confidential",
    'client_id': gitea_oauth2_client_id, 
    'client_secret': gitea_oauth2_client_secret,
    'access_code_validity': 'minutes=1',
    'token_validity': 'days=30',
    'include_claims_in_id_token': True,
    'jwt_alg': 'RS256',
    'rsa_key': self_signed_cert_id[0]["pk"],
    "redirect_uris": "",
    "sub_mode": "hashed_user_id",
    "issuer_mode": "per_provider"
}


# Create provider via /providers/oauth2
provider_oauth2_api_url = f"{base_url}/providers/oauth2"

res = requests.post(provider_oauth2_api_url,
    headers={'Authorization': f"Bearer {ak_admin_token}"},
    json=payload,
    allow_redirects=False)

# res = requests.get(provider_oauth2_api_url, headers={'Authorization': f"Bearer {ak_admin_token}"})

print(res.status_code)

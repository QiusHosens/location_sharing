use crate::provider::SmsProvider;
use async_trait::async_trait;
use chrono::Utc;
use hmac::{Hmac, KeyInit, Mac};
use sha1::Sha1;
use serde::Deserialize;
use std::collections::BTreeMap;

pub struct AliyunSmsProvider {
    access_key_id: String,
    access_key_secret: String,
    sign_name: String,
    template_code: String,
    client: reqwest::Client,
}

impl AliyunSmsProvider {
    pub fn new(
        access_key_id: String,
        access_key_secret: String,
        sign_name: String,
        template_code: String,
    ) -> Self {
        Self {
            access_key_id,
            access_key_secret,
            sign_name,
            template_code,
            client: reqwest::Client::new(),
        }
    }

    fn percent_encode(s: &str) -> String {
        let mut result = String::new();
        for byte in s.bytes() {
            match byte {
                b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                    result.push(byte as char);
                }
                _ => {
                    result.push_str(&format!("%{:02X}", byte));
                }
            }
        }
        result
    }

    fn sign(&self, params: &BTreeMap<&str, String>) -> String {
        let query = params
            .iter()
            .map(|(k, v)| format!("{}={}", Self::percent_encode(k), Self::percent_encode(v)))
            .collect::<Vec<_>>()
            .join("&");

        let string_to_sign = format!("GET&{}&{}", Self::percent_encode("/"), Self::percent_encode(&query));
        let signing_key = format!("{}&", self.access_key_secret);

        let mut mac = Hmac::<Sha1>::new_from_slice(signing_key.as_bytes())
            .expect("HMAC key length error");
        mac.update(string_to_sign.as_bytes());
        base64::Engine::encode(&base64::engine::general_purpose::STANDARD, mac.finalize().into_bytes())
    }
}

#[derive(Deserialize)]
struct AliyunResponse {
    #[serde(rename = "Code")]
    code: String,
    #[serde(rename = "Message")]
    message: Option<String>,
}

#[async_trait]
impl SmsProvider for AliyunSmsProvider {
    async fn send_code(&self, phone: &str, code: &str) -> anyhow::Result<()> {
        let nonce: String = uuid::Uuid::new_v4().to_string();
        let timestamp = Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let template_param = format!(r#"{{"code":"{}"}}"#, code);

        let mut params = BTreeMap::new();
        params.insert("AccessKeyId", self.access_key_id.clone());
        params.insert("Action", "SendSms".into());
        params.insert("Format", "JSON".into());
        params.insert("PhoneNumbers", phone.into());
        params.insert("RegionId", "cn-hangzhou".into());
        params.insert("SignName", self.sign_name.clone());
        params.insert("SignatureMethod", "HMAC-SHA1".into());
        params.insert("SignatureNonce", nonce);
        params.insert("SignatureVersion", "1.0".into());
        params.insert("TemplateCode", self.template_code.clone());
        params.insert("TemplateParam", template_param);
        params.insert("Timestamp", timestamp);
        params.insert("Version", "2017-05-25".into());

        let signature = self.sign(&params);
        params.insert("Signature", signature);

        let query = params
            .iter()
            .map(|(k, v)| format!("{}={}", k, Self::percent_encode(v)))
            .collect::<Vec<_>>()
            .join("&");

        let url = format!("https://dysmsapi.aliyuncs.com/?{}", query);
        let resp: AliyunResponse = self.client.get(&url).send().await?.json().await?;

        if resp.code != "OK" {
            anyhow::bail!("Aliyun SMS error: {} - {:?}", resp.code, resp.message);
        }

        tracing::info!(phone = phone, "SMS sent via Aliyun");
        Ok(())
    }
}

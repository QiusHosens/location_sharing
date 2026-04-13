use crate::provider::SmsProvider;
use async_trait::async_trait;
use chrono::Utc;
use hmac::{Hmac, Mac};
use sha2::Sha256;
use serde::{Deserialize, Serialize};

pub struct TencentSmsProvider {
    secret_id: String,
    secret_key: String,
    sdk_app_id: String,
    sign_name: String,
    template_id: String,
    client: reqwest::Client,
}

impl TencentSmsProvider {
    pub fn new(
        secret_id: String,
        secret_key: String,
        sdk_app_id: String,
        sign_name: String,
        template_id: String,
    ) -> Self {
        Self {
            secret_id,
            secret_key,
            sdk_app_id,
            sign_name,
            template_id,
            client: reqwest::Client::new(),
        }
    }
}

#[derive(Serialize)]
struct TencentRequest {
    #[serde(rename = "SmsSdkAppId")]
    sms_sdk_app_id: String,
    #[serde(rename = "SignName")]
    sign_name: String,
    #[serde(rename = "TemplateId")]
    template_id: String,
    #[serde(rename = "PhoneNumberSet")]
    phone_number_set: Vec<String>,
    #[serde(rename = "TemplateParamSet")]
    template_param_set: Vec<String>,
}

#[derive(Deserialize)]
struct TencentResponse {
    #[serde(rename = "Response")]
    response: TencentResponseInner,
}

#[derive(Deserialize)]
struct TencentResponseInner {
    #[serde(rename = "SendStatusSet")]
    send_status_set: Option<Vec<SendStatus>>,
    #[serde(rename = "Error")]
    error: Option<TencentError>,
}

#[derive(Deserialize)]
struct SendStatus {
    #[serde(rename = "Code")]
    code: String,
    #[serde(rename = "Message")]
    message: String,
}

#[derive(Deserialize)]
struct TencentError {
    #[serde(rename = "Code")]
    code: String,
    #[serde(rename = "Message")]
    message: String,
}

#[async_trait]
impl SmsProvider for TencentSmsProvider {
    async fn send_code(&self, phone: &str, code: &str) -> anyhow::Result<()> {
        let host = "sms.tencentcloudapi.com";
        let timestamp = Utc::now().timestamp();
        let date = Utc::now().format("%Y-%m-%d").to_string();

        let body = serde_json::to_string(&TencentRequest {
            sms_sdk_app_id: self.sdk_app_id.clone(),
            sign_name: self.sign_name.clone(),
            template_id: self.template_id.clone(),
            phone_number_set: vec![phone.to_string()],
            template_param_set: vec![code.to_string()],
        })?;

        let hashed_body = hex::encode(sha2::Digest::finalize(sha2::Digest::chain_update(
            sha2::Sha256::default(), body.as_bytes()
        )));

        let canonical_request = format!(
            "POST\n/\n\ncontent-type:application/json\nhost:{}\n\ncontent-type;host\n{}",
            host, hashed_body
        );
        let hashed_canonical = hex::encode(sha2::Digest::finalize(sha2::Digest::chain_update(
            sha2::Sha256::default(), canonical_request.as_bytes()
        )));

        let credential_scope = format!("{}/sms/tc3_request", date);
        let string_to_sign = format!(
            "TC3-HMAC-SHA256\n{}\n{}\n{}",
            timestamp, credential_scope, hashed_canonical
        );

        fn hmac_sha256(key: &[u8], data: &[u8]) -> Vec<u8> {
            let mut mac = Hmac::<Sha256>::new_from_slice(key).expect("HMAC key error");
            mac.update(data);
            mac.finalize().into_bytes().to_vec()
        }

        let secret_date = hmac_sha256(format!("TC3{}", self.secret_key).as_bytes(), date.as_bytes());
        let secret_service = hmac_sha256(&secret_date, b"sms");
        let secret_signing = hmac_sha256(&secret_service, b"tc3_request");
        let signature = hex::encode(hmac_sha256(&secret_signing, string_to_sign.as_bytes()));

        let authorization = format!(
            "TC3-HMAC-SHA256 Credential={}/{}, SignedHeaders=content-type;host, Signature={}",
            self.secret_id, credential_scope, signature
        );

        let resp: TencentResponse = self.client
            .post(format!("https://{}", host))
            .header("Content-Type", "application/json")
            .header("Host", host)
            .header("Authorization", &authorization)
            .header("X-TC-Action", "SendSms")
            .header("X-TC-Version", "2021-01-11")
            .header("X-TC-Timestamp", timestamp.to_string())
            .body(body)
            .send()
            .await?
            .json()
            .await?;

        if let Some(err) = resp.response.error {
            anyhow::bail!("Tencent SMS error: {} - {}", err.code, err.message);
        }

        if let Some(statuses) = resp.response.send_status_set {
            if let Some(s) = statuses.first() {
                if s.code != "Ok" {
                    anyhow::bail!("Tencent SMS send failed: {} - {}", s.code, s.message);
                }
            }
        }

        tracing::info!(phone = phone, "SMS sent via Tencent");
        Ok(())
    }
}

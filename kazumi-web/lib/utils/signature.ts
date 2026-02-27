/**
 * DanDanPlay API Signature Generation Utility
 * 
 * This utility generates authentication signatures for DanDanPlay API requests.
 * The signature ensures secure communication with the DanDanPlay service by
 * creating a cryptographic hash of the request parameters.
 */

import { createHash } from 'crypto';

/**
 * DanDanPlay API credentials
 */
const APP_ID = 'kvpx7qkqjh';
const SECRET = 'rABUaBLqdz7aCSi3fe88ZDj2gwga9Vax';

/**
 * Generates an authentication signature for DanDanPlay API requests.
 * 
 * Formula: Base64(SHA256(AppId + timestamp + path + SecretKey))
 * 
 * 照抄原项目 Utils.generateDandanSignature:
 * String data = id + timestamp.toString() + path + value;
 * var bytes = utf8.encode(data);
 * var digest = sha256.convert(bytes);
 * return base64Encode(digest.bytes);
 * 
 * @param timestamp - The current timestamp in SECONDS (not milliseconds!)
 * @param path - The API endpoint path (e.g., "/api/v2/comment/123")
 * @returns The Base64-encoded SHA256 signature
 */
export function generateDanDanPlaySignature(timestamp: string, path: string): string {
  // Construct the signature string: AppId + timestamp + path + SecretKey
  // 照抄原项目: String data = id + timestamp.toString() + path + value;
  const signatureString = `${APP_ID}${timestamp}${path}${SECRET}`;
  
  // Create SHA256 hash
  const hash = createHash('sha256');
  hash.update(signatureString);
  
  // Return Base64-encoded hash
  return hash.digest('base64');
}

/**
 * Get current timestamp in seconds (not milliseconds)
 * 照抄原项目: DateTime.now().millisecondsSinceEpoch ~/ 1000
 */
export function getDanDanPlayTimestamp(): string {
  return Math.floor(Date.now() / 1000).toString();
}

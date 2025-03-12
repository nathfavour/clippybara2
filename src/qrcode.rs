//! QR code scanning and generation functionality.

use std::io::Cursor;

use bardecoder;
use image::{ImageBuffer, Luma, Rgb};
use qrcode::QrCode;
use qrcode::render::svg;
use qrcode::render::unicode;

/// Generate a QR code as an SVG string from a URL
pub fn generate_svg(url: &str) -> String {
    let code = QrCode::new(url).unwrap();
    code.render::<svg::Color>()
        .min_dimensions(200, 200)
        .build()
}

/// Generate a QR code as a PNG image buffer
pub fn generate_png(url: &str, size: u32) -> ImageBuffer<Rgb<u8>, Vec<u8>> {
    let code = QrCode::new(url).unwrap();
    code.render::<Rgb<u8>>()
        .min_dimensions(size, size)
        .build()
}

/// Generate a QR code as a printable string (for terminal display)
pub fn generate_terminal(url: &str) -> String {
    let code = QrCode::new(url).unwrap();
    code.render::<unicode::Dense1x2>()
        .dark_color(unicode::Dense1x2::Light)
        .light_color(unicode::Dense1x2::Dark)
        .build()
}

/// Scan a QR code from an image buffer
pub fn scan_qrcode(image_data: &[u8]) -> Result<String, String> {
    match image::load_from_memory(image_data) {
        Ok(img) => {
            let decoder = bardecoder::default_decoder();
            let results = decoder.decode(&img);
            
            // Filter out empty or erroneous results
            let valid_results: Vec<_> = results
                .into_iter()
                .filter_map(|result| result.ok())
                .filter(|text| !text.is_empty())
                .collect();
            
            if let Some(first_result) = valid_results.first() {
                Ok(first_result.clone())
            } else {
                Err("No QR code found in image".to_string())
            }
        }
        Err(e) => Err(format!("Failed to decode image: {}", e)),
    }
}

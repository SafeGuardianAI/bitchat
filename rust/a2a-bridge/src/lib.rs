pub fn round_trip(input: String) -> String {
    format!("rust:{input}")
}

pub fn a2a_version() -> String {
    a2a::VERSION.to_owned()
}

uniffi::include_scaffolding!("bitchat_a2a");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_is_stable() {
        assert_eq!(round_trip("swift".into()), "rust:swift");
        assert_eq!(a2a_version(), "1.0");
    }
}

// SPDX-License-Identifier: MIT

#![cfg_attr(not(test), no_std)]

/// Command identifiers shared between the TA and host applications.
///
/// These values must match the command IDs sent from the host to the trusted
/// application via OP-TEE Secure World RPC calls.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Command {
    IncValue = 0,
    DecValue = 1,
}

impl Command {
    /// Converts a raw command ID to a [`Command`], returning `None` for unknown IDs.
    pub fn from_raw(value: u32) -> Option<Self> {
        match value {
            0 => Some(Command::IncValue),
            1 => Some(Command::DecValue),
            _ => None,
        }
    }

    /// Converts this command back to its raw u32 representation.
    pub fn as_raw(self) -> u32 {
        self as u32
    }
}

impl From<Command> for u32 {
    fn from(cmd: Command) -> Self {
        cmd.as_raw()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_from_raw_inc() {
        assert_eq!(Command::from_raw(0), Some(Command::IncValue));
    }

    #[test]
    fn test_from_raw_dec() {
        assert_eq!(Command::from_raw(1), Some(Command::DecValue));
    }

    #[test]
    fn test_from_raw_invalid() {
        assert_eq!(Command::from_raw(2), None);
    }

    #[test]
    fn test_as_raw_inc() {
        assert_eq!(Command::IncValue.as_raw(), 0);
    }

    #[test]
    fn test_as_raw_dec() {
        assert_eq!(Command::DecValue.as_raw(), 1);
    }
}

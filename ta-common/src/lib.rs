// SPDX-License-Identifier: MIT

#![cfg_attr(not(test), no_std)]
use anyhow::{bail, Error as AnyError};
use core::convert::TryFrom;

/// Command identifiers shared between the TA and host applications.
///
/// These values must match the command IDs sent from the host to the trusted
/// application via OP-TEE Secure World RPC calls.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Command {
    IncValue = 0,
    DecValue = 1,
}

impl TryFrom<u32> for Command {
    type Error = AnyError;

    /// Attempts to convert a raw `u32` value into a `Command` enum variant.
    fn try_from(value: u32) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Command::IncValue),
            1 => Ok(Command::DecValue),
            _ => bail!("Invalid command ID"),
        }
    }
}

impl From<Command> for u32 {
    /// Converts a `Command` enum variant into its raw `u32` representation.
    fn from(cmd: Command) -> Self {
        cmd as u32
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_from_raw_inc() {
        assert_eq!(
            Command::try_from(0).expect("Expected success"),
            Command::IncValue
        );
    }

    #[test]
    fn test_from_raw_dec() {
        assert_eq!(
            Command::try_from(1).expect("Expected success"),
            Command::DecValue
        );
    }

    #[test]
    fn test_from_raw_invalid() {
        assert!(Command::try_from(2).is_err());
    }

    #[test]
    fn test_as_raw_inc() {
        assert_eq!(u32::from(Command::IncValue), 0);
    }

    #[test]
    fn test_as_raw_dec() {
        assert_eq!(u32::from(Command::DecValue), 1);
    }
}

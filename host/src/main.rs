// SPDX-License-Identifier: MIT

use optee_teec::{Context, Operation, ParamNone, ParamType, ParamValue, Result, Uuid};

// TA_UUID is generated at build time from uuid.txt and included via read_uuid.rs.
include!(concat!(env!("OUT_DIR"), "/read_uuid.rs"));

const TEST_VALUE: u32 = 42;

/// Command IDs — must match the values defined in the TA.
enum Command {
    IncValue = 0,
    DecValue = 1,
}

impl From<Command> for u32 {
    fn from(cmd: Command) -> Self {
        cmd as u32
    }
}

fn main() -> Result<()> {
    // Open a session to the hello_world TA.
    let mut session = Context::new()?.open_session(Uuid::parse_str(TA_UUID)?)?;

    // Build an operation with one value parameter + three unused slots.
    let mut op1 = Operation::new(
        0,
        ParamValue::new(TEST_VALUE, 0, ParamType::ValueInout),
        ParamNone,
        ParamNone,
        ParamNone,
    );
    println!("Sending value to TA: {}", op1.parameters().0.a());
    session.invoke_command(Command::IncValue.into(), &mut op1)?;
    let value = op1.parameters().0.a();
    println!("TA echoed (incremented) value to {}", value);

    // (Optional) Invoke command 1 (decrement) to verify round-trip.
    let mut op2 = Operation::new(
        0,
        ParamValue::new(value, 0, ParamType::ValueInout),
        ParamNone,
        ParamNone,
        ParamNone,
    );
    session.invoke_command(Command::DecValue.into(), &mut op2)?;
    let value2 = op2.parameters().0.a();
    println!("TA decreased value back to {}", value2);

    // Session and context close automatically via Drop — no explicit close needed.
    println!("Done");

    Ok(())
}

use optee_teec::{Context, Operation, ParamNone, ParamType, ParamValue, Uuid};

// TA_UUID is generated at build time from uuid.txt and included via read_uuid.rs.
include!(concat!(env!("OUT_DIR"), "/read_uuid.rs"));

/// Command IDs — must match the values defined in the TA.
const TA_CMD_INC_VALUE: u32 = 0;
const TA_CMD_DEC_VALUE: u32 = 1;

fn main() -> optee_teec::Result<()> {
    // Initialize a context connecting us to the TEE.
    let mut ctx = Context::new()?;

    // Parse the TA's UUID from a string.
    let uuid = Uuid::parse_str(TA_UUID)?;

    // Open a session to the hello_world TA.
    let mut session = ctx.open_session(uuid)?;

    // Create an input value to send to the TA.
    let p0 = ParamValue::new(42, 0, ParamType::ValueInout);

    // Build an operation with one value parameter + three unused slots.
    let mut op1 = Operation::new(0, p0, ParamNone, ParamNone, ParamNone);

    // Read the value before invoking the TA (just for debugging).
    println!("Sending value to TA: {}", op1.parameters().0.a());

    // Invoke command 0 (increment/echo).
    session.invoke_command(TA_CMD_INC_VALUE, &mut op1)?;

    // Read the value back after the TA has processed it.
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
    session.invoke_command(TA_CMD_DEC_VALUE, &mut op2)?;
    let value2 = op2.parameters().0.a();
    println!("TA decreased value back to {}", value2);

    // Session and context close automatically via Drop — no explicit close needed.
    println!("Done");

    Ok(())
}

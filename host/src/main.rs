use optee_teec::{Context, Operation, ParamNone, ParamType, ParamValue, Uuid};

/// UUID of the hello_world_ta Trusted Application.
/// Must match the UUID in ta/uuid.txt.
const TA_UUID: &str = "6b23a879-3c3b-4f80-a836-83721d27622f";

/// Command IDs — must match the values defined in the TA.
const TA_CMD_INC_VALUE: u32 = 0;
const TA_CMD_DEC_VALUE: u32 = 1;

fn main() -> optee_teec::Result<()> {
    // 1. Initialize a context connecting us to the TEE.
    let mut ctx = Context::new()?;

    // 2. Parse the TA's UUID from a string.
    let uuid = Uuid::parse_str(TA_UUID)?;

    // 3. Open a session to the hello_world TA.
    let mut session = ctx.open_session(uuid)?;

    // 4. Create an input value to send to the TA.
    let p0 = ParamValue::new(42, 0, ParamType::ValueInout);

    // 5. Build an operation with one value parameter + three unused slots.
    let mut operation = Operation::new(0, p0, ParamNone, ParamNone, ParamNone);

    // 6. Read the value before invoking the TA (just for debugging).
    println!("Sending value to TA: {}", operation.parameters().0.a());

    // 7. Invoke command 0 (increment/echo).
    session.invoke_command(TA_CMD_INC_VALUE, &mut operation)?;

    // 8. Read the value back after the TA has processed it.
    let value = operation.parameters().0.a();
    println!("TA echoed (incremented) value to {}", value);

    // 9. (Optional) Invoke command 1 (decrement) to verify round-trip.
    let mut operation2 = Operation::new(
        0,
        ParamValue::new(value, 0, ParamType::ValueInout),
        ParamNone,
        ParamNone,
        ParamNone,
    );
    session.invoke_command(TA_CMD_DEC_VALUE, &mut operation2)?;
    let value2 = operation2.parameters().0.a();
    println!("TA decreased value back to {}", value2);

    // Session and context close automatically via Drop — no explicit close needed.
    println!("Done");

    Ok(())
}

module dante.types.nop;

public class NopRequest
{
    this()
    {
        import davinci.c2s.test;
        import davinci;
        TestMessage testMessage = new TestMessage();
        super(new BaseMessage(MessageType.CLIENT_TO_SERVER, CommandType.NOP_COMMAND, testMessage).encode());
    }
}
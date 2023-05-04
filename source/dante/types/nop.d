module dante.types.nop;

import tasky : Request;

public class NopRequest : Request
{
    this()
    {
        import davinci.c2s.test;
        TestMessage testMessage = new TestMessage();
        super(testMessage.encode());
    }
}
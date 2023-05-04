module dante.types.nop;

import tasky : Request;

public class NopRequest : Request
{
    this()
    {
        super(cast(byte[])"ABBA");
    }
}
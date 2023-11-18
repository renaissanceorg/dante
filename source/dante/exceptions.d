module dante.exceptions;

public abstract class DanteException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

public class CommandException : DanteException
{
    this(string msg)
    {
        super(msg);
    }
}

import std.conv : to;

public class ProtocolException : DanteException
{
    this(string msg)
    {
        super(msg);
    }

    public static ProtocolException expectedMessageKind(TypeInfo_Class expected, Object got)
    {
        string message = "Expected message of type '"~to!(string)(expected);

        if(got is null)
        {
            message ~= " but got null";
        }
        else
        {
            message ~= " but got a message of type '"~to!(string)(got.classinfo)~"'";
        }

        return new ProtocolException(message);
    }
}
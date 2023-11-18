module dante.tings;

import dante;
import dante.exceptions : ProtocolException;
import davinci.base : Command;
public mixin template Expect_n_handle(ExpectedType, alias command)
if(__traits(isSame, typeof(command), Command))
{
    /** 
     * Check that we can cast to `ExpectedType`
     *
     * If not, we throw anexception
     */
    ExpectedType expectedMessage = cast(ExpectedType)command;
    
    

    void Expect_n_handle()
    {
        import std.stdio : writeln;
        writeln("Hello testing");
        if(expectedMessage is null)
        {
            throw ProtocolException.expectedMessageKind(expectedMessage.classinfo, command);
        }
    }
}
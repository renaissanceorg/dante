module dante.client;

import std.socket;
import river.core;
import river.impls.sock : SockStream;
import davinci;

import tristanable;
import guillotine;
import guillotine.providers.sequential;

version(dbg)
{
    import std.stdio;
}

public class DanteClient
{
    /** 
     * The underlying stream connecting us to
     * the endpoint server
     */
    private Stream connection;

    /** 
     * Tristanable manager
     */
    private Manager manager;

    /** 
     * Guillotine engine
     */
    private Executor executor;
    private Provider provider;

    // TODO: We do this because maybe lookup DNS rather than Address and then decice
    // ... on whetherto make a TLS stream or not
    this(string domain, ushort port)
    {
        // TODO: TLS check etc? Then construct a CryptCLient stream ...

        // TODO: Exception handling for DNS resolution
        // TODO: Preference over which record to use
        Address resolvedAddress = getAddress(domain, port)[0];
        this(resolvedAddress);
    }

    // TODO: Are we sure we want to do this?
    // as this connects immediately, then again all of these do
    // actually (the stream based one assumes an opened stream is passed in)
    this(Address endpointAddress)
    {
        Socket clientSocket = new Socket(endpointAddress.addressFamily(), SocketType.STREAM);
        // TODO: Exception handling (for the `connect()` call)
        clientSocket.connect(endpointAddress);
        this(new SockStream(clientSocket));
    }

    /** 
     * Creates a new Dante client based on the provided stream
     *
     * Params:
     *   connection = the stream to the server
     */
    this(Stream connection)
    {
        this.connection = connection;

        /* Create a tristanable manager based on this */
        this.manager = new Manager(connection);

        /* Create a provider (for the executor) and start it */ // TODO: change later to multi-threaded one or something
        this.provider = new Sequential();
        this.provider.start();

        /* Create a task executor */
        this.executor = new Executor(this.provider);
    }

    public void start()
    {
        /* Start the tristanable manager */
        manager.start();
        version(dbg) { writeln("Dante staretd tristanable manager..."); }
    }

    public void stop()
    {
        /* Stop the tristanable manager */
        manager.stop();

        /* Stop the task executor's provider */
        provider.stop();
    }

    public Future nopRequest()
    {
        import davinci.c2s.test;
        import davinci;
        NopMessage testMessage = new NopMessage();
        
        BaseMessage msg = new BaseMessage(MessageType.CLIENT_TO_SERVER, CommandType.NOP_COMMAND, testMessage);

        // TODO: Encode message
        // TODO: Send with tristanable
        // TODO: Wrap a tristanable  `dequeue()` in a FutureTask via guillotine and return that
        Queue uniqueQueue = this.manager.getUniqueQueue();


        BaseMessage doRequest()
        {
            TaggedMessage message = new TaggedMessage(uniqueQueue.getID(), msg.encode());
            this.manager.sendMessage(message);

            TaggedMessage response = uniqueQueue.dequeue();
            return BaseMessage.decode(response.getPayload());
        }

        Future future = this.executor.submitTask!(doRequest);

        return future;
    }

    
}

version(unittest)
{
    import std.stdio : writeln;
}

unittest
{
    DanteClient client = new DanteClient(new UnixAddress("/tmp/renaissance.sock"));
    client.start();

    Future fut = client.nopRequest();

    writeln("Awaitinf future...");
    Result res = fut.await();
    writeln("Awaitinf future... [done]");
    writeln("Future result: ", res.getValue().value.object);

    client.stop();
}
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
        version(dbg) { writeln("Dante started tristanable manager..."); }
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
        testMessage.setTestField("Lekker Boetie");

        BaseMessage msg = new BaseMessage(MessageType.CLIENT_TO_SERVER, CommandType.NOP_COMMAND, testMessage);

        return makeRequest(msg);
    }

    public Future authenticate(string username, string password)
    {
        import davinci.c2s.auth;
        import davinci;
        AuthMessage authMessage = new AuthMessage();
        authMessage.setUsername(username);
        authMessage.setPassword(password);

        BaseMessage msg = new BaseMessage(MessageType.CLIENT_TO_SERVER, CommandType.AUTH_COMMAND, authMessage);

        // TODO: We should handle auth here for the user, instead of just returning a future?

        return makeRequest(msg);
    }

    public Future enumerateChannels_imp(ulong offset, ubyte limit)
    {
        import davinci.c2s.channels : ChannelEnumerateRequest;
        import davinci;
        ChannelEnumerateRequest chanEnumReq = new ChannelEnumerateRequest();
        

        BaseMessage msg = new BaseMessage(MessageType.CLIENT_TO_SERVER, CommandType.CHANNELS_ENUMERATE_REQ, chanEnumReq);

        // TODO: We should handle auth here for the user, instead of just returning a future?

        return makeRequest(msg);
    }

    public string[] enumerateChannels(ulong offset, ubyte limit)
    {
        import davinci.c2s.channels : ChannelEnumerateReply;
        BaseMessage response = cast(BaseMessage)enumerateChannels_imp(offset, limit).await().getValue().value.object;

        ChannelEnumerateReply responseCommand = cast(ChannelEnumerateReply)response.getCommand();

        return responseCommand.getChannels();
    }

    public string[] enumerateChannels()
    {
        return enumerateChannels(0, 0);
    }

    /** 
     * Makes a request and returns a future which
     * can be awaited on for when the request
     * is fulfilled server-side.
     *
     * This method automatically manages
     * the queueing for you.
     *
     * Params:
     *   request = the request message
     * Returns: a `Future`
     */
    private Future makeRequest(BaseMessage request)
    {
        // Obtain a unique queue for this request
        Queue uniqueQueue = this.manager.getUniqueQueue();

        return makeRequest(request, uniqueQueue, true);
    }

    /** 
     * Makes a request described by the provided message
     * which, we will then return a future which will
     * wait for a reply on the queue provided.
     *
     * Params:
     *   request = the request message
     *   responseQueue = the queue which the future
     * should await a reply from on
     *   releaseAfterUse = whether or not to automatically
     * deregister the provided queue after completion. Default
     * is `false`.
     * 
     * Returns: a `Future`
     */
    private Future makeRequest(BaseMessage request, Queue responseQueue, bool releaseAfterUse = false)
    {
        byte[] encoded = request.encode();

        // BUG: If you tried encoding INSIDE of the delegate/closure then runtime probelm with msgpack
        // ... hence I encode outside and then refer to it inside. TELL MSGPACK people about this!
        BaseMessage doRequest()
        {
            TaggedMessage message = new TaggedMessage(responseQueue.getID(), encoded);
            this.manager.sendMessage(message);

            TaggedMessage response = responseQueue.dequeue();

            if(releaseAfterUse)
            {
                // De-register queue here to prevent resource leak
                // ... and allow queue id recycling
                this.manager.releaseQueue(responseQueue);
            }

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

unittest
{
    DanteClient client = new DanteClient(new UnixAddress("/tmp/renaissance.sock"));
    client.start();

    Future fut = client.authenticate("deavmi", "testpassword");

    writeln("Awaitinf future...");
    Result res = fut.await();
    writeln("Awaitinf future... [done]");
    writeln("Future result: ", res.getValue().value.object);

    client.stop();
}

version(unittest)
{
    import niknaks.debugging : dumpArray;
}

unittest
{
    DanteClient client = new DanteClient(new UnixAddress("/tmp/renaissance.sock"));
    client.start();

    writeln("Waiting for channels...");
    string[] channels = client.enumerateChannels();
    writeln(dumpArray!(channels));

    client.stop();
}
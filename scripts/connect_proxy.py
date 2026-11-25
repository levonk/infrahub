import asyncio

async def pipe(r, w):
    try:
        while True:
            d = await r.read(65536)
            if not d:
                break
            w.write(d)
            await w.drain()
    except Exception:
        pass
    finally:
        try:
            w.close()
        except Exception:
            pass

async def handle(reader, writer):
    try:
        head = await reader.readuntil(b"\r\n\r\n")
        line = head.split(b"\r\n", 1)[0].decode()
        if not line.startswith("CONNECT "):
            writer.write(b"HTTP/1.1 405 Method Not Allowed\r\n\r\n")
            await writer.drain()
            writer.close()
            return
        host, port = line.split()[1].rsplit(":", 1)
        r2, w2 = await asyncio.open_connection(host, int(port))
        writer.write(b"HTTP/1.1 200 Connection established\r\n\r\n")
        await writer.drain()
        await asyncio.gather(pipe(reader, w2), pipe(r2, writer))
    except Exception:
        try:
            writer.close()
        except Exception:
            pass

async def main():
    srv = await asyncio.start_server(handle, "127.0.0.1", 8899)
    async with srv:
        await srv.serve_forever()

asyncio.run(main())

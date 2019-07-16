import std.experimental.logger;
import std.typecons:tuple;

import zfs.constants: Checksum, Compression;




ubyte[] decompress(ubyte[] data, Compression mode, int size, T inherit=null)
{
    if mode == Compression.INHERIT:
        mode = inherit
    if mode in (Compression.ON, Compression.LZJB):
        return bytes(lzjb.decompress(data, size))
    elif mode == Compression.LZ4 and lz4:
        length = struct.unpack('>I', data[:4])[0]
        data = data[4:length + 4]
        return lz4.block.decompress(struct.pack('<i', size) + data)
    elif mode.name.startswith('GZIP_'):
        data = zlib.decompress(data)
        return data[:size]
    elif mode == Compression.OFF:
        return data
    else:
        if mode == Compression.LZ4 and not lz4:
            logging.error("Got a block with lz4 compression, but don't have `lz4` available")
	raise ValueError(mode)
}


alias ChecksumType = Tuple!(int, int, int, int);


bool checksum(ubyte[] data, ChecksumType valid, Checksum mode, Checksum inherit = None, ChecksumType chk = None)
{
	valid = tuple(valid);
	switch(mode) with(Checksum)
	{
		case INHERIT:
			mode = inherit;
			break;
		case FLETCHER_4:
			mode = fletcher4(data);
			break;
		case FLETCHER_2:
			mode = fletcher2(data);
			break;
		case SHA256:
			mode = sha256(data);
			break;
		case OFF:
			return true;
		default:
			throw new Exception(mode.to!string);
	}
	
	return all(c == v for c, v in zip(chk, valid))
}


ChecksumTYpe sha256(ubyte[] data)
{
    return struct.unpack('>QQQQ', hashlib.sha256(data).digest());
}


auto unpack(ubyte[] data, string code)
{
    auto s = struct.calcsize(code);
    return struct.unpack(code*int(len(data)/s), data);
}


ChecksumType fletcher2(ubyte[] data)
{
	enum mod = 1 << 64
	un_data = list(unpack(data, 'Q'))
	long a,b,c,d;
	foreach(first, second in zip(un_data[0::2], un_data[1::2]))
	{
		a = (a + first) % mod;
		b = (b + second) % mod;
		c = (c + a) % mod;
		d = (d + b) % mod;
	}
	return a, b, c, d;
}


ChecksumType fletcher4(ubyte[] data)
{
	enum mod = 1 << 64;
	long a,b,c,d;
	foeach(w;data) // w in unpack(data, 'I'):
	{
		a = (a + w) % mod;
		b = (b + a) % mod;
		c = (c + b) % mod;
		d = (d + c) % mod;
	}
	return a, b, c, d;
}

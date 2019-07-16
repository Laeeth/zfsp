module zfs.filedev;
import zfs.vdevs;


struct FileDev
{
	VDev vdev;

	this(string path, string label, string txg)
	{
		this.f = File(path,"r+b");
		vdev(label,txg);
	}

	auto read(size_t offset, size_t size)
	{
		f.seek(offset);
		return f.read(size);
	}

	auto write(size_t offset, ubyte[] data)
	{
		return f.write(data);
	}

	auto flush()
	{
		return f.flush();
	}

	auto seek(size_t offset, size_t whence)
	{
		return f.seek(offset,whence);
	}
}


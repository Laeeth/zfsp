import std.experimental.logger;
import zfs.nvlist;
import zfs.ondisk;

enum LABEL_PAD = 16384;
enum UBER_AREA = 1024 * 128;  // 128 uberblock areas, each 1KiB long


struct VDev
{
    enum LABELS = [
        [0, os.SEEK_SET],
        [262144, os.SEEK_SET],
        [-262144, os.SEEK_END],
        [-524288, os.SEEK_END],
	]; 

    this(label_index: int=None, txg: int=None)
    {
        self.labels = [self.read_label(l) for l in self.LABELS];
        self.label = self.best_label = self._best_label(label_index);
        self.id = self.label[b'vdev_tree'][b'id'];
        self.raw_uberblocks = [u for _, ubers in self.labels for u in ubers];
        self.uberblocks = self.parse_uberblocks(self.raw_uberblocks);
        self.active_uberblock = self.select_uberblock(txg);
    }

    Uberblock[] parse_uberblocks(Uberblock[] raw_uberblocks)
    {
        uber_list = list(filter(ondisk.Uberblock.valid, raw_uberblocks))
        uber_list.sort(key=lambda x: x.txg, reverse=True)
        return uber_list;
    }

    Uberblock select_uberblock(int txg)
    {
        txgs_available = sorted(list(set(x.txg for x in self.uberblocks)))
        if txg in txgs_available:
            logger.info('TXGs available: {}'.format(txgs_available))
            candidates = [x for x in self.uberblocks if x.txg == txg]
            active_uberblock = candidates[0]
        else:
            if txg:
                logger.error('Did not find desired txg {} on device {}'.format(txg, self))
                logger.info('TXGs available: {}'.format(txgs_available))
            active_uberblock = self.uberblocks[0]
        return active_uberblock
    }

    def _best_label(label_index: int=None):
        retprops = {b'txg': 0}
        for label in self.labels:
            props = label[0]
            if props[b'txg'] > retprops[b'txg']:
                retprops = props
        if label_index:
            best_label = self.labels[label_index]
        else:
            best_label = retprops
        return best_label

	auto read_label(int[2] label)
	{
		data = self.read(label, 262144)
		# skip the reserved padding
		data = data[LABEL_PAD:]
		# pull the nvdata out
		nvdata = data[:nvlist.NVAREA]
		data = data[nvlist.NVAREA:]
		# parse the nv data
		properties = nvlist.NVList(nvdata).unpack_nvlist()
		# get the uberblock section (should be the rest of data)
		uberblock_array = data[:UBER_AREA]
		uberblocks = []
		for elem in range(128):
			elem *= 1024
			this_block = uberblock_array[elem:elem + 1024]
			b = ondisk.Uberblock(this_block)
			# print repr(this_block)
			b.unpack(this_block)
			uberblocks.append(b)
		return properties, uberblocks
	}

    ubyte[] read_dva(dva: ondisk.dva) -> bytes
    {
        offset = (dva.offset * 512) + 0x400000;
        data = self.read((offset, 0), dva.asize * 512);
        return data;
    }

    ubyte[] read(offset: Union[int, Tuple[int, int]], size: int)
    {
        raise NotImplementedError;
    }
}

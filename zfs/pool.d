import std.experimental.logger;
import std.path;

import zfs.constants;
import zfs.objectset;
import zfs.readcontext;
import zfs.datasets;
import zfs.vdevs;
import zfs.posix;


auto vdev_list_to_dict(VDev[] vdevs)
{
    auto d = [];
    foreach(v;vdevs)
        d[v.id] = v;
    return d;
}


struct Pool
{
	this(vdevs: List[vdevs.VDev], try_config=None)
	{
		this.vdevs = vdev_list_to_dict(vdevs);
		this.default_compression = constants.Compression.LZJB
		this.default_checksum = constants.Checksum.FLETCHER_4
		this.ashift = this.first_vdev().best_label[b'vdev_tree'][b'ashift']
		this.version = this.first_vdev().best_label[b'version']
		this.try_config = try_config or set()
		this._meta_object_sets = {}
	}

	VDev first_vdev()
	{
		return list(this.vdevs.values()).front;
	}

	ReadContext context()
	{
		return .ReadContext(
			this.vdevs,
			this.default_compression,
			this.default_checksum,
			this.ashift,
			this.try_config
		);
	}

	ubyte[] read_block(blkptr)
	{
		return this.context().read_block(blkptr);
	}

	ubyte[] read_indirect(blkptr)
	{
		return this.context().read_indirect(blkptr);
	}

	ubyte[] read_dnode(dnode)
	{
		return this.context().read_dnode(dnode);
	}

	ubyte[] read_file(string path)
	{
		pathes = os.path.split(path)
		if len(pathes) != 2:
		    raise NotImplementedError
		filename = pathes[-1]
		dir_ents = this.open(pathes[0])
		if filename not in dir_ents:
		    raise OSError("file not found: {}".format(filename))
		return dir_ents[filename].read()
	}


	Objectset objset_for_vdev(V)(V vdev)
	if (is(T==int) ||(T==Vdev))
	{
		if (isinstance(vdev, int))
		    vdev = this.vdevs[vdev];
		auto root = this.read_indirect(vdev.active_uberblock.root);
		auto vdev_id = vdev.id;
		if (vdev_id !in this._meta_object_sets)
		    this._meta_object_sets[vdev_id] = ObjectSet.from_block(root);
		return this._meta_object_sets[vdev_id];
	}

	Dataset root_dataset()
	{
		auto objset = this.objset_for_vdev(this.first_vdev());
		auto dir_index = objset[1]['root_dataset'];
		auto dataset = objset[dir_index];
		return dataset;
	}

	auto metaslab_array()
	{
		location = this.first_vdev().best_label[b'metaslab_array'];
		return this.objset_for_vdev(this.first_vdev())[location];
	}

	Dataset dataset_for(string dataset_expr)
	{
		if '@' not in dataset_expr:
		    dataset_expr += '@'
		dataset_name, snapshot_name = dataset_expr.split('@', 1)
		ds = this.open(dataset_name)
		enforce(isinstance(ds, datasets.Dataset),"key error");
		return ds.snapshots.get(snapshot_name, ds);
	}

    def open(path: str) -> Union[datasets.Dataset, posix.Directory]:
        paths = path.lstrip('/').split('/')
        current = this.root_dataset
        if paths == ['']:
            return current
        for next_dir in paths:
            current = current[next_dir]
        return current

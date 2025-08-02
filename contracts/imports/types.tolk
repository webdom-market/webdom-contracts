type SerializableSlice = slice;

fun SerializableSlice.unpackFromSlice(mutate s: slice) {
    val serializableSlice = s;
    s = createEmptySlice(); 
    return serializableSlice;
}

fun SerializableSlice.packToBuilder(self, mutate b: builder) {
    b.storeSlice(self);
}

type AddressBuilder = builder;

fun AddressBuilder.unpackFromSlice(mutate s: slice) {
    val addressBuilder = beginCell().storeSlice(s);
    s = createEmptySlice(); 
    return addressBuilder;
}

fun AddressBuilder.packToBuilder(self, mutate b: builder) {
    b.storeBuilder(self);
}
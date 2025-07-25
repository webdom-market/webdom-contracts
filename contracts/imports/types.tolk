type SerializableSlice = slice

fun SerializableSlice.unpackFromSlice(mutate s: slice) {
    val serializableSlice = s;
    s = createEmptySlice(); 
    return serializableSlice
}

fun SerializableSlice.packToBuilder(self, mutate b: builder) {
    b.storeSlice(self)
}
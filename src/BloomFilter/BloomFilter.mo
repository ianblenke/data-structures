import Array "mo:base/Array";
import Float "mo:base/Float";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Word "mo:base/Word32";

module {

  type Hash = Hash.Hash;

  /// Manages BloomFilters, deploys new BloomFilters, and checks for element membership across filters.
  /// Args:
  ///   |capacity|    The maximum number of elements a BlooomFilter may store.
  ///   |errorRate|   The maximum false positive rate a BloomFilter may maintain.
  ///   |hashFuncs|   The hash functions used to hash elements into the filter.
  public class AutoScalingBloomFilter<S>(capacity: Nat, errorRate: Float, hashFuncs: [(S) -> Hash]) {

    var filters: [BloomFilter<S>] = [];

    let numSlices = Float.ceil(Float.log(1.0 / errorRate));
    let bitsPerSlice = Float.ceil(
          (Float.fromInt(capacity) * Float.abs(Float.log(errorRate))) /
          (numSlices * (Float.log(2) ** 2)));
    let bitMapSize: Nat = Int.abs(Float.toInt(numSlices * bitsPerSlice));

    /// Adds an element to the BloomFilter's bitmap and deploys new BloomFilter if previous is at capacity.
    /// Args:
    ///   |item|   The item to be added.
    public func add(item: S) {
      var filter = BloomFilter(bitMapSize, hashFuncs);
      if (filters.size() > 0) {
        let last_filter = filters[filters.size() - 1];
        if (last_filter.getNumItems() < capacity) {
          filter := last_filter;
        };
      };
      filter.add(item);
      filters := Array.append<BloomFilter<S>>(filters, [filter]);
    };

    /// Checks if an item is contained in any BloomFilters
    /// Args:
    ///   |item|   The item to be searched for.
    /// Returns:
    ///   A boolean indicating set membership.
    public func check(item: S) : Bool {
      for (filter in Iter.fromArray(filters)) {
        if (filter.check(item)) { return true; };
      };
      false
    };

  };

  /// The specific BloomFilter implementation used in AutoScalingBloomFilter.
  /// Args:
  ///   |bitMapSize|    The size of the bitmap (as determined in AutoScalingBloomFilter).
  ///   |hashFuncs|     The hash functions used to hash elements into the filter.
  public class BloomFilter<S>(bitMapSize: Nat, hashFuncs: [(S) -> Hash]) {

    var numItems = 0;
    let bitMap: [var Bool] = Array.init<Bool>(bitMapSize, false);

    public func add(item: S) {
      for (f in Iter.fromArray(hashFuncs)) {
        let digest = Word.toNat(f(item)) % bitMapSize;
        bitMap[digest] := true;
      };
      numItems += 1;
    };

    public func check(item: S) : Bool {
      for (f in Iter.fromArray(hashFuncs)) {
        let digest = Word.toNat(f(item)) % bitMapSize;
        if (bitMap[digest] == true) return false;
      };
      true
    };

    public func getNumItems() : Nat {
      numItems
    };

    public func getBitMap() : [Bool] {
      Array.freeze(bitMap)
    };

    public func setData(data: [Bool]) {
      assert data.size() == bitMapSize;
      for (i in Iter.range(0, data.size())) {
        bitMap[i] := data[i];
      };
    };

  };

};
/// Small LRU cache for engine output.
///
/// Engines are pure functions of `(kernel, system, params, size)`, so their
/// geometry is built once per key and only reveal lengths, transforms and
/// uniforms change per frame.
class GeometryCache<V> {
  GeometryCache({this.capacity = 32});

  final int capacity;
  final Map<Object, V> _map = <Object, V>{};

  V putIfAbsent(Object key, V Function() build) {
    final hit = _map.remove(key);
    if (hit != null) {
      _map[key] = hit;
      return hit;
    }
    final value = build();
    _map[key] = value;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
    return value;
  }

  int get length => _map.length;

  void clear() => _map.clear();
}

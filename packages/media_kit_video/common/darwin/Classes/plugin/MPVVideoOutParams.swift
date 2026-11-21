#if SWIFT_PACKAGE
  import Mpv
#endif

public class MPVVideoOutParams {
  public let dw: Int64
  public let dh: Int64
  public let rotate: Int64

  init(
    dw: Int64,
    dh: Int64,
    rotate: Int64
  ) {
    self.dw = dw
    self.dh = dh
    self.rotate = rotate
  }

  public static let empty = MPVVideoOutParams(
    dw: 0,
    dh: 0,
    rotate: 0
  )

  public static func fromMPVNodeList(
    _ map: mpv_node_list
  ) -> MPVVideoOutParams {
    var dw: Int64 = 0
    var dh: Int64 = 0
    var rotate: Int64 = 0

    var kptr = map.keys!
    var vptr = map.values!
    for _ in 0 ..< map.num {
      let key = String(cString: kptr.pointee!)
      let value: mpv_node = vptr.pointee

      kptr = kptr.successor()
      vptr = vptr.successor()

      if value.format == MPV_FORMAT_INT64 {
        if key == "dw" {
          dw = value.u.int64
        } else if key == "dh" {
          dh = value.u.int64
        } else if key == "rotate" {
          rotate = value.u.int64
        }
      }
    }

    return MPVVideoOutParams(
      dw: dw,
      dh: dh,
      rotate: rotate
    )
  }
}

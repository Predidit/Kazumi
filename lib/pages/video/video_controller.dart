import 'package:kazumi/modules/roads/road_module.dart';
import 'package:mobx/mobx.dart';

part 'video_controller.g.dart';

class VideoController = _VideoController with _$VideoController;

abstract class _VideoController with Store {
  @observable
  var roadList = ObservableList<Road>();
}

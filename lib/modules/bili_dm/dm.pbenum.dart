//
//  Generated code. Do not modify.
//  source: bilibili/community/service/dm/v1/dm.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class AvatarType extends $pb.ProtobufEnum {
  static const AvatarType AvatarTypeNone = AvatarType._(0, _omitEnumNames ? '' : 'AvatarTypeNone');
  static const AvatarType AvatarTypeNFT = AvatarType._(1, _omitEnumNames ? '' : 'AvatarTypeNFT');

  static const $core.List<AvatarType> values = <AvatarType> [
    AvatarTypeNone,
    AvatarTypeNFT,
  ];

  static final $core.Map<$core.int, AvatarType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static AvatarType? valueOf($core.int value) => _byValue[value];

  const AvatarType._($core.int v, $core.String n) : super(v, n);
}

class BubbleType extends $pb.ProtobufEnum {
  static const BubbleType BubbleTypeNone = BubbleType._(0, _omitEnumNames ? '' : 'BubbleTypeNone');
  static const BubbleType BubbleTypeClickButton = BubbleType._(1, _omitEnumNames ? '' : 'BubbleTypeClickButton');
  static const BubbleType BubbleTypeDmSettingPanel = BubbleType._(2, _omitEnumNames ? '' : 'BubbleTypeDmSettingPanel');

  static const $core.List<BubbleType> values = <BubbleType> [
    BubbleTypeNone,
    BubbleTypeClickButton,
    BubbleTypeDmSettingPanel,
  ];

  static final $core.Map<$core.int, BubbleType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static BubbleType? valueOf($core.int value) => _byValue[value];

  const BubbleType._($core.int v, $core.String n) : super(v, n);
}

class CheckboxType extends $pb.ProtobufEnum {
  static const CheckboxType CheckboxTypeNone = CheckboxType._(0, _omitEnumNames ? '' : 'CheckboxTypeNone');
  static const CheckboxType CheckboxTypeEncourage = CheckboxType._(1, _omitEnumNames ? '' : 'CheckboxTypeEncourage');
  static const CheckboxType CheckboxTypeColorDM = CheckboxType._(2, _omitEnumNames ? '' : 'CheckboxTypeColorDM');

  static const $core.List<CheckboxType> values = <CheckboxType> [
    CheckboxTypeNone,
    CheckboxTypeEncourage,
    CheckboxTypeColorDM,
  ];

  static final $core.Map<$core.int, CheckboxType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CheckboxType? valueOf($core.int value) => _byValue[value];

  const CheckboxType._($core.int v, $core.String n) : super(v, n);
}

/// 弹幕属性位值
class DMAttrBit extends $pb.ProtobufEnum {
  static const DMAttrBit DMAttrBitProtect = DMAttrBit._(0, _omitEnumNames ? '' : 'DMAttrBitProtect');
  static const DMAttrBit DMAttrBitFromLive = DMAttrBit._(1, _omitEnumNames ? '' : 'DMAttrBitFromLive');
  static const DMAttrBit DMAttrHighLike = DMAttrBit._(2, _omitEnumNames ? '' : 'DMAttrHighLike');

  static const $core.List<DMAttrBit> values = <DMAttrBit> [
    DMAttrBitProtect,
    DMAttrBitFromLive,
    DMAttrHighLike,
  ];

  static final $core.Map<$core.int, DMAttrBit> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DMAttrBit? valueOf($core.int value) => _byValue[value];

  const DMAttrBit._($core.int v, $core.String n) : super(v, n);
}

class DmColorfulType extends $pb.ProtobufEnum {
  static const DmColorfulType NoneType = DmColorfulType._(0, _omitEnumNames ? '' : 'NoneType');
  static const DmColorfulType VipGradualColor = DmColorfulType._(60001, _omitEnumNames ? '' : 'VipGradualColor');

  static const $core.List<DmColorfulType> values = <DmColorfulType> [
    NoneType,
    VipGradualColor,
  ];

  static final $core.Map<$core.int, DmColorfulType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DmColorfulType? valueOf($core.int value) => _byValue[value];

  const DmColorfulType._($core.int v, $core.String n) : super(v, n);
}

class ExposureType extends $pb.ProtobufEnum {
  static const ExposureType ExposureTypeNone = ExposureType._(0, _omitEnumNames ? '' : 'ExposureTypeNone');
  static const ExposureType ExposureTypeDMSend = ExposureType._(1, _omitEnumNames ? '' : 'ExposureTypeDMSend');

  static const $core.List<ExposureType> values = <ExposureType> [
    ExposureTypeNone,
    ExposureTypeDMSend,
  ];

  static final $core.Map<$core.int, ExposureType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ExposureType? valueOf($core.int value) => _byValue[value];

  const ExposureType._($core.int v, $core.String n) : super(v, n);
}

class PostPanelBizType extends $pb.ProtobufEnum {
  static const PostPanelBizType PostPanelBizTypeNone = PostPanelBizType._(0, _omitEnumNames ? '' : 'PostPanelBizTypeNone');
  static const PostPanelBizType PostPanelBizTypeEncourage = PostPanelBizType._(1, _omitEnumNames ? '' : 'PostPanelBizTypeEncourage');
  static const PostPanelBizType PostPanelBizTypeColorDM = PostPanelBizType._(2, _omitEnumNames ? '' : 'PostPanelBizTypeColorDM');
  static const PostPanelBizType PostPanelBizTypeNFTDM = PostPanelBizType._(3, _omitEnumNames ? '' : 'PostPanelBizTypeNFTDM');
  static const PostPanelBizType PostPanelBizTypeFragClose = PostPanelBizType._(4, _omitEnumNames ? '' : 'PostPanelBizTypeFragClose');
  static const PostPanelBizType PostPanelBizTypeRecommend = PostPanelBizType._(5, _omitEnumNames ? '' : 'PostPanelBizTypeRecommend');

  static const $core.List<PostPanelBizType> values = <PostPanelBizType> [
    PostPanelBizTypeNone,
    PostPanelBizTypeEncourage,
    PostPanelBizTypeColorDM,
    PostPanelBizTypeNFTDM,
    PostPanelBizTypeFragClose,
    PostPanelBizTypeRecommend,
  ];

  static final $core.Map<$core.int, PostPanelBizType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PostPanelBizType? valueOf($core.int value) => _byValue[value];

  const PostPanelBizType._($core.int v, $core.String n) : super(v, n);
}

class PostStatus extends $pb.ProtobufEnum {
  static const PostStatus PostStatusNormal = PostStatus._(0, _omitEnumNames ? '' : 'PostStatusNormal');
  static const PostStatus PostStatusClosed = PostStatus._(1, _omitEnumNames ? '' : 'PostStatusClosed');

  static const $core.List<PostStatus> values = <PostStatus> [
    PostStatusNormal,
    PostStatusClosed,
  ];

  static final $core.Map<$core.int, PostStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PostStatus? valueOf($core.int value) => _byValue[value];

  const PostStatus._($core.int v, $core.String n) : super(v, n);
}

class RenderType extends $pb.ProtobufEnum {
  static const RenderType RenderTypeNone = RenderType._(0, _omitEnumNames ? '' : 'RenderTypeNone');
  static const RenderType RenderTypeSingle = RenderType._(1, _omitEnumNames ? '' : 'RenderTypeSingle');
  static const RenderType RenderTypeRotation = RenderType._(2, _omitEnumNames ? '' : 'RenderTypeRotation');

  static const $core.List<RenderType> values = <RenderType> [
    RenderTypeNone,
    RenderTypeSingle,
    RenderTypeRotation,
  ];

  static final $core.Map<$core.int, RenderType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static RenderType? valueOf($core.int value) => _byValue[value];

  const RenderType._($core.int v, $core.String n) : super(v, n);
}

class SubtitleAiStatus extends $pb.ProtobufEnum {
  static const SubtitleAiStatus None = SubtitleAiStatus._(0, _omitEnumNames ? '' : 'None');
  static const SubtitleAiStatus Exposure = SubtitleAiStatus._(1, _omitEnumNames ? '' : 'Exposure');
  static const SubtitleAiStatus Assist = SubtitleAiStatus._(2, _omitEnumNames ? '' : 'Assist');

  static const $core.List<SubtitleAiStatus> values = <SubtitleAiStatus> [
    None,
    Exposure,
    Assist,
  ];

  static final $core.Map<$core.int, SubtitleAiStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SubtitleAiStatus? valueOf($core.int value) => _byValue[value];

  const SubtitleAiStatus._($core.int v, $core.String n) : super(v, n);
}

class SubtitleAiType extends $pb.ProtobufEnum {
  static const SubtitleAiType Normal = SubtitleAiType._(0, _omitEnumNames ? '' : 'Normal');
  static const SubtitleAiType Translate = SubtitleAiType._(1, _omitEnumNames ? '' : 'Translate');

  static const $core.List<SubtitleAiType> values = <SubtitleAiType> [
    Normal,
    Translate,
  ];

  static final $core.Map<$core.int, SubtitleAiType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SubtitleAiType? valueOf($core.int value) => _byValue[value];

  const SubtitleAiType._($core.int v, $core.String n) : super(v, n);
}

class SubtitleType extends $pb.ProtobufEnum {
  static const SubtitleType CC = SubtitleType._(0, _omitEnumNames ? '' : 'CC');
  static const SubtitleType AI = SubtitleType._(1, _omitEnumNames ? '' : 'AI');

  static const $core.List<SubtitleType> values = <SubtitleType> [
    CC,
    AI,
  ];

  static final $core.Map<$core.int, SubtitleType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SubtitleType? valueOf($core.int value) => _byValue[value];

  const SubtitleType._($core.int v, $core.String n) : super(v, n);
}

class ToastFunctionType extends $pb.ProtobufEnum {
  static const ToastFunctionType ToastFunctionTypeNone = ToastFunctionType._(0, _omitEnumNames ? '' : 'ToastFunctionTypeNone');
  static const ToastFunctionType ToastFunctionTypePostPanel = ToastFunctionType._(1, _omitEnumNames ? '' : 'ToastFunctionTypePostPanel');

  static const $core.List<ToastFunctionType> values = <ToastFunctionType> [
    ToastFunctionTypeNone,
    ToastFunctionTypePostPanel,
  ];

  static final $core.Map<$core.int, ToastFunctionType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ToastFunctionType? valueOf($core.int value) => _byValue[value];

  const ToastFunctionType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');

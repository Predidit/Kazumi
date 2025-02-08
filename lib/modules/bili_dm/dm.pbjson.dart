//
//  Generated code. Do not modify.
//  source: bilibili/community/service/dm/v1/dm.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use avatarTypeDescriptor instead')
const AvatarType$json = {
  '1': 'AvatarType',
  '2': [
    {'1': 'AvatarTypeNone', '2': 0},
    {'1': 'AvatarTypeNFT', '2': 1},
  ],
};

/// Descriptor for `AvatarType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List avatarTypeDescriptor = $convert.base64Decode(
    'CgpBdmF0YXJUeXBlEhIKDkF2YXRhclR5cGVOb25lEAASEQoNQXZhdGFyVHlwZU5GVBAB');

@$core.Deprecated('Use bubbleTypeDescriptor instead')
const BubbleType$json = {
  '1': 'BubbleType',
  '2': [
    {'1': 'BubbleTypeNone', '2': 0},
    {'1': 'BubbleTypeClickButton', '2': 1},
    {'1': 'BubbleTypeDmSettingPanel', '2': 2},
  ],
};

/// Descriptor for `BubbleType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List bubbleTypeDescriptor = $convert.base64Decode(
    'CgpCdWJibGVUeXBlEhIKDkJ1YmJsZVR5cGVOb25lEAASGQoVQnViYmxlVHlwZUNsaWNrQnV0dG'
    '9uEAESHAoYQnViYmxlVHlwZURtU2V0dGluZ1BhbmVsEAI=');

@$core.Deprecated('Use checkboxTypeDescriptor instead')
const CheckboxType$json = {
  '1': 'CheckboxType',
  '2': [
    {'1': 'CheckboxTypeNone', '2': 0},
    {'1': 'CheckboxTypeEncourage', '2': 1},
    {'1': 'CheckboxTypeColorDM', '2': 2},
  ],
};

/// Descriptor for `CheckboxType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List checkboxTypeDescriptor = $convert.base64Decode(
    'CgxDaGVja2JveFR5cGUSFAoQQ2hlY2tib3hUeXBlTm9uZRAAEhkKFUNoZWNrYm94VHlwZUVuY2'
    '91cmFnZRABEhcKE0NoZWNrYm94VHlwZUNvbG9yRE0QAg==');

@$core.Deprecated('Use dMAttrBitDescriptor instead')
const DMAttrBit$json = {
  '1': 'DMAttrBit',
  '2': [
    {'1': 'DMAttrBitProtect', '2': 0},
    {'1': 'DMAttrBitFromLive', '2': 1},
    {'1': 'DMAttrHighLike', '2': 2},
  ],
};

/// Descriptor for `DMAttrBit`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dMAttrBitDescriptor = $convert.base64Decode(
    'CglETUF0dHJCaXQSFAoQRE1BdHRyQml0UHJvdGVjdBAAEhUKEURNQXR0ckJpdEZyb21MaXZlEA'
    'ESEgoORE1BdHRySGlnaExpa2UQAg==');

@$core.Deprecated('Use dmColorfulTypeDescriptor instead')
const DmColorfulType$json = {
  '1': 'DmColorfulType',
  '2': [
    {'1': 'NoneType', '2': 0},
    {'1': 'VipGradualColor', '2': 60001},
  ],
};

/// Descriptor for `DmColorfulType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dmColorfulTypeDescriptor = $convert.base64Decode(
    'Cg5EbUNvbG9yZnVsVHlwZRIMCghOb25lVHlwZRAAEhUKD1ZpcEdyYWR1YWxDb2xvchDh1AM=');

@$core.Deprecated('Use exposureTypeDescriptor instead')
const ExposureType$json = {
  '1': 'ExposureType',
  '2': [
    {'1': 'ExposureTypeNone', '2': 0},
    {'1': 'ExposureTypeDMSend', '2': 1},
  ],
};

/// Descriptor for `ExposureType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exposureTypeDescriptor = $convert.base64Decode(
    'CgxFeHBvc3VyZVR5cGUSFAoQRXhwb3N1cmVUeXBlTm9uZRAAEhYKEkV4cG9zdXJlVHlwZURNU2'
    'VuZBAB');

@$core.Deprecated('Use postPanelBizTypeDescriptor instead')
const PostPanelBizType$json = {
  '1': 'PostPanelBizType',
  '2': [
    {'1': 'PostPanelBizTypeNone', '2': 0},
    {'1': 'PostPanelBizTypeEncourage', '2': 1},
    {'1': 'PostPanelBizTypeColorDM', '2': 2},
    {'1': 'PostPanelBizTypeNFTDM', '2': 3},
    {'1': 'PostPanelBizTypeFragClose', '2': 4},
    {'1': 'PostPanelBizTypeRecommend', '2': 5},
  ],
};

/// Descriptor for `PostPanelBizType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List postPanelBizTypeDescriptor = $convert.base64Decode(
    'ChBQb3N0UGFuZWxCaXpUeXBlEhgKFFBvc3RQYW5lbEJpelR5cGVOb25lEAASHQoZUG9zdFBhbm'
    'VsQml6VHlwZUVuY291cmFnZRABEhsKF1Bvc3RQYW5lbEJpelR5cGVDb2xvckRNEAISGQoVUG9z'
    'dFBhbmVsQml6VHlwZU5GVERNEAMSHQoZUG9zdFBhbmVsQml6VHlwZUZyYWdDbG9zZRAEEh0KGV'
    'Bvc3RQYW5lbEJpelR5cGVSZWNvbW1lbmQQBQ==');

@$core.Deprecated('Use postStatusDescriptor instead')
const PostStatus$json = {
  '1': 'PostStatus',
  '2': [
    {'1': 'PostStatusNormal', '2': 0},
    {'1': 'PostStatusClosed', '2': 1},
  ],
};

/// Descriptor for `PostStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List postStatusDescriptor = $convert.base64Decode(
    'CgpQb3N0U3RhdHVzEhQKEFBvc3RTdGF0dXNOb3JtYWwQABIUChBQb3N0U3RhdHVzQ2xvc2VkEA'
    'E=');

@$core.Deprecated('Use renderTypeDescriptor instead')
const RenderType$json = {
  '1': 'RenderType',
  '2': [
    {'1': 'RenderTypeNone', '2': 0},
    {'1': 'RenderTypeSingle', '2': 1},
    {'1': 'RenderTypeRotation', '2': 2},
  ],
};

/// Descriptor for `RenderType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List renderTypeDescriptor = $convert.base64Decode(
    'CgpSZW5kZXJUeXBlEhIKDlJlbmRlclR5cGVOb25lEAASFAoQUmVuZGVyVHlwZVNpbmdsZRABEh'
    'YKElJlbmRlclR5cGVSb3RhdGlvbhAC');

@$core.Deprecated('Use subtitleAiStatusDescriptor instead')
const SubtitleAiStatus$json = {
  '1': 'SubtitleAiStatus',
  '2': [
    {'1': 'None', '2': 0},
    {'1': 'Exposure', '2': 1},
    {'1': 'Assist', '2': 2},
  ],
};

/// Descriptor for `SubtitleAiStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List subtitleAiStatusDescriptor = $convert.base64Decode(
    'ChBTdWJ0aXRsZUFpU3RhdHVzEggKBE5vbmUQABIMCghFeHBvc3VyZRABEgoKBkFzc2lzdBAC');

@$core.Deprecated('Use subtitleAiTypeDescriptor instead')
const SubtitleAiType$json = {
  '1': 'SubtitleAiType',
  '2': [
    {'1': 'Normal', '2': 0},
    {'1': 'Translate', '2': 1},
  ],
};

/// Descriptor for `SubtitleAiType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List subtitleAiTypeDescriptor = $convert.base64Decode(
    'Cg5TdWJ0aXRsZUFpVHlwZRIKCgZOb3JtYWwQABINCglUcmFuc2xhdGUQAQ==');

@$core.Deprecated('Use subtitleTypeDescriptor instead')
const SubtitleType$json = {
  '1': 'SubtitleType',
  '2': [
    {'1': 'CC', '2': 0},
    {'1': 'AI', '2': 1},
  ],
};

/// Descriptor for `SubtitleType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List subtitleTypeDescriptor = $convert.base64Decode(
    'CgxTdWJ0aXRsZVR5cGUSBgoCQ0MQABIGCgJBSRAB');

@$core.Deprecated('Use toastFunctionTypeDescriptor instead')
const ToastFunctionType$json = {
  '1': 'ToastFunctionType',
  '2': [
    {'1': 'ToastFunctionTypeNone', '2': 0},
    {'1': 'ToastFunctionTypePostPanel', '2': 1},
  ],
};

/// Descriptor for `ToastFunctionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List toastFunctionTypeDescriptor = $convert.base64Decode(
    'ChFUb2FzdEZ1bmN0aW9uVHlwZRIZChVUb2FzdEZ1bmN0aW9uVHlwZU5vbmUQABIeChpUb2FzdE'
    'Z1bmN0aW9uVHlwZVBvc3RQYW5lbBAB');

@$core.Deprecated('Use avatarDescriptor instead')
const Avatar$json = {
  '1': 'Avatar',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'avatar_type', '3': 3, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.AvatarType', '10': 'avatarType'},
  ],
};

/// Descriptor for `Avatar`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List avatarDescriptor = $convert.base64Decode(
    'CgZBdmF0YXISDgoCaWQYASABKAlSAmlkEhAKA3VybBgCIAEoCVIDdXJsEk0KC2F2YXRhcl90eX'
    'BlGAMgASgOMiwuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuQXZhdGFyVHlwZVIK'
    'YXZhdGFyVHlwZQ==');

@$core.Deprecated('Use bubbleDescriptor instead')
const Bubble$json = {
  '1': 'Bubble',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `Bubble`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bubbleDescriptor = $convert.base64Decode(
    'CgZCdWJibGUSEgoEdGV4dBgBIAEoCVIEdGV4dBIQCgN1cmwYAiABKAlSA3VybA==');

@$core.Deprecated('Use bubbleV2Descriptor instead')
const BubbleV2$json = {
  '1': 'BubbleV2',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'bubble_type', '3': 3, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.BubbleType', '10': 'bubbleType'},
    {'1': 'exposure_once', '3': 4, '4': 1, '5': 8, '10': 'exposureOnce'},
    {'1': 'exposure_type', '3': 5, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.ExposureType', '10': 'exposureType'},
  ],
};

/// Descriptor for `BubbleV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bubbleV2Descriptor = $convert.base64Decode(
    'CghCdWJibGVWMhISCgR0ZXh0GAEgASgJUgR0ZXh0EhAKA3VybBgCIAEoCVIDdXJsEk0KC2J1Ym'
    'JsZV90eXBlGAMgASgOMiwuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuQnViYmxl'
    'VHlwZVIKYnViYmxlVHlwZRIjCg1leHBvc3VyZV9vbmNlGAQgASgIUgxleHBvc3VyZU9uY2USUw'
    'oNZXhwb3N1cmVfdHlwZRgFIAEoDjIuLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYx'
    'LkV4cG9zdXJlVHlwZVIMZXhwb3N1cmVUeXBl');

@$core.Deprecated('Use buttonDescriptor instead')
const Button$json = {
  '1': 'Button',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'action', '3': 2, '4': 1, '5': 5, '10': 'action'},
  ],
};

/// Descriptor for `Button`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buttonDescriptor = $convert.base64Decode(
    'CgZCdXR0b24SEgoEdGV4dBgBIAEoCVIEdGV4dBIWCgZhY3Rpb24YAiABKAVSBmFjdGlvbg==');

@$core.Deprecated('Use buzzwordConfigDescriptor instead')
const BuzzwordConfig$json = {
  '1': 'BuzzwordConfig',
  '2': [
    {'1': 'keywords', '3': 1, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.BuzzwordShowConfig', '10': 'keywords'},
  ],
};

/// Descriptor for `BuzzwordConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buzzwordConfigDescriptor = $convert.base64Decode(
    'Cg5CdXp6d29yZENvbmZpZxJQCghrZXl3b3JkcxgBIAMoCzI0LmJpbGliaWxpLmNvbW11bml0eS'
    '5zZXJ2aWNlLmRtLnYxLkJ1enp3b3JkU2hvd0NvbmZpZ1IIa2V5d29yZHM=');

@$core.Deprecated('Use buzzwordShowConfigDescriptor instead')
const BuzzwordShowConfig$json = {
  '1': 'BuzzwordShowConfig',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'schema', '3': 2, '4': 1, '5': 9, '10': 'schema'},
    {'1': 'source', '3': 3, '4': 1, '5': 5, '10': 'source'},
    {'1': 'id', '3': 4, '4': 1, '5': 3, '10': 'id'},
    {'1': 'buzzword_id', '3': 5, '4': 1, '5': 3, '10': 'buzzwordId'},
    {'1': 'schema_type', '3': 6, '4': 1, '5': 5, '10': 'schemaType'},
  ],
};

/// Descriptor for `BuzzwordShowConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buzzwordShowConfigDescriptor = $convert.base64Decode(
    'ChJCdXp6d29yZFNob3dDb25maWcSEgoEbmFtZRgBIAEoCVIEbmFtZRIWCgZzY2hlbWEYAiABKA'
    'lSBnNjaGVtYRIWCgZzb3VyY2UYAyABKAVSBnNvdXJjZRIOCgJpZBgEIAEoA1ICaWQSHwoLYnV6'
    'endvcmRfaWQYBSABKANSCmJ1enp3b3JkSWQSHwoLc2NoZW1hX3R5cGUYBiABKAVSCnNjaGVtYV'
    'R5cGU=');

@$core.Deprecated('Use checkBoxDescriptor instead')
const CheckBox$json = {
  '1': 'CheckBox',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.CheckboxType', '10': 'type'},
    {'1': 'default_value', '3': 3, '4': 1, '5': 8, '10': 'defaultValue'},
    {'1': 'show', '3': 4, '4': 1, '5': 8, '10': 'show'},
  ],
};

/// Descriptor for `CheckBox`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkBoxDescriptor = $convert.base64Decode(
    'CghDaGVja0JveBISCgR0ZXh0GAEgASgJUgR0ZXh0EkIKBHR5cGUYAiABKA4yLi5iaWxpYmlsaS'
    '5jb21tdW5pdHkuc2VydmljZS5kbS52MS5DaGVja2JveFR5cGVSBHR5cGUSIwoNZGVmYXVsdF92'
    'YWx1ZRgDIAEoCFIMZGVmYXVsdFZhbHVlEhIKBHNob3cYBCABKAhSBHNob3c=');

@$core.Deprecated('Use checkBoxV2Descriptor instead')
const CheckBoxV2$json = {
  '1': 'CheckBoxV2',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'type', '3': 2, '4': 1, '5': 5, '10': 'type'},
    {'1': 'default_value', '3': 3, '4': 1, '5': 8, '10': 'defaultValue'},
  ],
};

/// Descriptor for `CheckBoxV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkBoxV2Descriptor = $convert.base64Decode(
    'CgpDaGVja0JveFYyEhIKBHRleHQYASABKAlSBHRleHQSEgoEdHlwZRgCIAEoBVIEdHlwZRIjCg'
    '1kZWZhdWx0X3ZhbHVlGAMgASgIUgxkZWZhdWx0VmFsdWU=');

@$core.Deprecated('Use clickButtonDescriptor instead')
const ClickButton$json = {
  '1': 'ClickButton',
  '2': [
    {'1': 'portrait_text', '3': 1, '4': 3, '5': 9, '10': 'portraitText'},
    {'1': 'landscape_text', '3': 2, '4': 3, '5': 9, '10': 'landscapeText'},
    {'1': 'portrait_text_focus', '3': 3, '4': 3, '5': 9, '10': 'portraitTextFocus'},
    {'1': 'landscape_text_focus', '3': 4, '4': 3, '5': 9, '10': 'landscapeTextFocus'},
    {'1': 'render_type', '3': 5, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.RenderType', '10': 'renderType'},
    {'1': 'show', '3': 6, '4': 1, '5': 8, '10': 'show'},
    {'1': 'bubble', '3': 7, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.Bubble', '10': 'bubble'},
  ],
};

/// Descriptor for `ClickButton`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickButtonDescriptor = $convert.base64Decode(
    'CgtDbGlja0J1dHRvbhIjCg1wb3J0cmFpdF90ZXh0GAEgAygJUgxwb3J0cmFpdFRleHQSJQoObG'
    'FuZHNjYXBlX3RleHQYAiADKAlSDWxhbmRzY2FwZVRleHQSLgoTcG9ydHJhaXRfdGV4dF9mb2N1'
    'cxgDIAMoCVIRcG9ydHJhaXRUZXh0Rm9jdXMSMAoUbGFuZHNjYXBlX3RleHRfZm9jdXMYBCADKA'
    'lSEmxhbmRzY2FwZVRleHRGb2N1cxJNCgtyZW5kZXJfdHlwZRgFIAEoDjIsLmJpbGliaWxpLmNv'
    'bW11bml0eS5zZXJ2aWNlLmRtLnYxLlJlbmRlclR5cGVSCnJlbmRlclR5cGUSEgoEc2hvdxgGIA'
    'EoCFIEc2hvdxJACgZidWJibGUYByABKAsyKC5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5k'
    'bS52MS5CdWJibGVSBmJ1YmJsZQ==');

@$core.Deprecated('Use clickButtonV2Descriptor instead')
const ClickButtonV2$json = {
  '1': 'ClickButtonV2',
  '2': [
    {'1': 'portrait_text', '3': 1, '4': 3, '5': 9, '10': 'portraitText'},
    {'1': 'landscape_text', '3': 2, '4': 3, '5': 9, '10': 'landscapeText'},
    {'1': 'portrait_text_focus', '3': 3, '4': 3, '5': 9, '10': 'portraitTextFocus'},
    {'1': 'landscape_text_focus', '3': 4, '4': 3, '5': 9, '10': 'landscapeTextFocus'},
    {'1': 'render_type', '3': 5, '4': 1, '5': 5, '10': 'renderType'},
    {'1': 'text_input_post', '3': 6, '4': 1, '5': 8, '10': 'textInputPost'},
    {'1': 'exposure_once', '3': 7, '4': 1, '5': 8, '10': 'exposureOnce'},
    {'1': 'exposure_type', '3': 8, '4': 1, '5': 5, '10': 'exposureType'},
  ],
};

/// Descriptor for `ClickButtonV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clickButtonV2Descriptor = $convert.base64Decode(
    'Cg1DbGlja0J1dHRvblYyEiMKDXBvcnRyYWl0X3RleHQYASADKAlSDHBvcnRyYWl0VGV4dBIlCg'
    '5sYW5kc2NhcGVfdGV4dBgCIAMoCVINbGFuZHNjYXBlVGV4dBIuChNwb3J0cmFpdF90ZXh0X2Zv'
    'Y3VzGAMgAygJUhFwb3J0cmFpdFRleHRGb2N1cxIwChRsYW5kc2NhcGVfdGV4dF9mb2N1cxgEIA'
    'MoCVISbGFuZHNjYXBlVGV4dEZvY3VzEh8KC3JlbmRlcl90eXBlGAUgASgFUgpyZW5kZXJUeXBl'
    'EiYKD3RleHRfaW5wdXRfcG9zdBgGIAEoCFINdGV4dElucHV0UG9zdBIjCg1leHBvc3VyZV9vbm'
    'NlGAcgASgIUgxleHBvc3VyZU9uY2USIwoNZXhwb3N1cmVfdHlwZRgIIAEoBVIMZXhwb3N1cmVU'
    'eXBl');

@$core.Deprecated('Use commandDmDescriptor instead')
const CommandDm$json = {
  '1': 'CommandDm',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'mid', '3': 3, '4': 1, '5': 9, '10': 'mid'},
    {'1': 'command', '3': 4, '4': 1, '5': 9, '10': 'command'},
    {'1': 'content', '3': 5, '4': 1, '5': 9, '10': 'content'},
    {'1': 'progress', '3': 6, '4': 1, '5': 5, '10': 'progress'},
    {'1': 'ctime', '3': 7, '4': 1, '5': 9, '10': 'ctime'},
    {'1': 'mtime', '3': 8, '4': 1, '5': 9, '10': 'mtime'},
    {'1': 'extra', '3': 9, '4': 1, '5': 9, '10': 'extra'},
    {'1': 'idStr', '3': 10, '4': 1, '5': 9, '10': 'idStr'},
  ],
};

/// Descriptor for `CommandDm`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandDmDescriptor = $convert.base64Decode(
    'CglDb21tYW5kRG0SDgoCaWQYASABKANSAmlkEhAKA29pZBgCIAEoA1IDb2lkEhAKA21pZBgDIA'
    'EoCVIDbWlkEhgKB2NvbW1hbmQYBCABKAlSB2NvbW1hbmQSGAoHY29udGVudBgFIAEoCVIHY29u'
    'dGVudBIaCghwcm9ncmVzcxgGIAEoBVIIcHJvZ3Jlc3MSFAoFY3RpbWUYByABKAlSBWN0aW1lEh'
    'QKBW10aW1lGAggASgJUgVtdGltZRIUCgVleHRyYRgJIAEoCVIFZXh0cmESFAoFaWRTdHIYCiAB'
    'KAlSBWlkU3Ry');

@$core.Deprecated('Use danmakuAIFlagDescriptor instead')
const DanmakuAIFlag$json = {
  '1': 'DanmakuAIFlag',
  '2': [
    {'1': 'dm_flags', '3': 1, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmakuFlag', '10': 'dmFlags'},
  ],
};

/// Descriptor for `DanmakuAIFlag`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmakuAIFlagDescriptor = $convert.base64Decode(
    'Cg1EYW5tYWt1QUlGbGFnEkgKCGRtX2ZsYWdzGAEgAygLMi0uYmlsaWJpbGkuY29tbXVuaXR5Ln'
    'NlcnZpY2UuZG0udjEuRGFubWFrdUZsYWdSB2RtRmxhZ3M=');

@$core.Deprecated('Use danmakuElemDescriptor instead')
const DanmakuElem$json = {
  '1': 'DanmakuElem',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'progress', '3': 2, '4': 1, '5': 5, '10': 'progress'},
    {'1': 'mode', '3': 3, '4': 1, '5': 5, '10': 'mode'},
    {'1': 'fontsize', '3': 4, '4': 1, '5': 5, '10': 'fontsize'},
    {'1': 'color', '3': 5, '4': 1, '5': 13, '10': 'color'},
    {'1': 'midHash', '3': 6, '4': 1, '5': 9, '10': 'midHash'},
    {'1': 'content', '3': 7, '4': 1, '5': 9, '10': 'content'},
    {'1': 'ctime', '3': 8, '4': 1, '5': 3, '10': 'ctime'},
    {'1': 'weight', '3': 9, '4': 1, '5': 5, '10': 'weight'},
    {'1': 'action', '3': 10, '4': 1, '5': 9, '10': 'action'},
    {'1': 'pool', '3': 11, '4': 1, '5': 5, '10': 'pool'},
    {'1': 'idStr', '3': 12, '4': 1, '5': 9, '10': 'idStr'},
    {'1': 'attr', '3': 13, '4': 1, '5': 5, '10': 'attr'},
    {'1': 'animation', '3': 22, '4': 1, '5': 9, '10': 'animation'},
    {'1': 'colorful', '3': 24, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.DmColorfulType', '10': 'colorful'},
  ],
};

/// Descriptor for `DanmakuElem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmakuElemDescriptor = $convert.base64Decode(
    'CgtEYW5tYWt1RWxlbRIOCgJpZBgBIAEoA1ICaWQSGgoIcHJvZ3Jlc3MYAiABKAVSCHByb2dyZX'
    'NzEhIKBG1vZGUYAyABKAVSBG1vZGUSGgoIZm9udHNpemUYBCABKAVSCGZvbnRzaXplEhQKBWNv'
    'bG9yGAUgASgNUgVjb2xvchIYCgdtaWRIYXNoGAYgASgJUgdtaWRIYXNoEhgKB2NvbnRlbnQYBy'
    'ABKAlSB2NvbnRlbnQSFAoFY3RpbWUYCCABKANSBWN0aW1lEhYKBndlaWdodBgJIAEoBVIGd2Vp'
    'Z2h0EhYKBmFjdGlvbhgKIAEoCVIGYWN0aW9uEhIKBHBvb2wYCyABKAVSBHBvb2wSFAoFaWRTdH'
    'IYDCABKAlSBWlkU3RyEhIKBGF0dHIYDSABKAVSBGF0dHISHAoJYW5pbWF0aW9uGBYgASgJUglh'
    'bmltYXRpb24STAoIY29sb3JmdWwYGCABKA4yMC5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS'
    '5kbS52MS5EbUNvbG9yZnVsVHlwZVIIY29sb3JmdWw=');

@$core.Deprecated('Use danmakuFlagDescriptor instead')
const DanmakuFlag$json = {
  '1': 'DanmakuFlag',
  '2': [
    {'1': 'dmid', '3': 1, '4': 1, '5': 3, '10': 'dmid'},
    {'1': 'flag', '3': 2, '4': 1, '5': 13, '10': 'flag'},
  ],
};

/// Descriptor for `DanmakuFlag`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmakuFlagDescriptor = $convert.base64Decode(
    'CgtEYW5tYWt1RmxhZxISCgRkbWlkGAEgASgDUgRkbWlkEhIKBGZsYWcYAiABKA1SBGZsYWc=');

@$core.Deprecated('Use danmakuFlagConfigDescriptor instead')
const DanmakuFlagConfig$json = {
  '1': 'DanmakuFlagConfig',
  '2': [
    {'1': 'rec_flag', '3': 1, '4': 1, '5': 5, '10': 'recFlag'},
    {'1': 'rec_text', '3': 2, '4': 1, '5': 9, '10': 'recText'},
    {'1': 'rec_switch', '3': 3, '4': 1, '5': 5, '10': 'recSwitch'},
  ],
};

/// Descriptor for `DanmakuFlagConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmakuFlagConfigDescriptor = $convert.base64Decode(
    'ChFEYW5tYWt1RmxhZ0NvbmZpZxIZCghyZWNfZmxhZxgBIAEoBVIHcmVjRmxhZxIZCghyZWNfdG'
    'V4dBgCIAEoCVIHcmVjVGV4dBIdCgpyZWNfc3dpdGNoGAMgASgFUglyZWNTd2l0Y2g=');

@$core.Deprecated('Use danmuDefaultPlayerConfigDescriptor instead')
const DanmuDefaultPlayerConfig$json = {
  '1': 'DanmuDefaultPlayerConfig',
  '2': [
    {'1': 'player_danmaku_use_default_config', '3': 1, '4': 1, '5': 8, '10': 'playerDanmakuUseDefaultConfig'},
    {'1': 'player_danmaku_ai_recommended_switch', '3': 4, '4': 1, '5': 8, '10': 'playerDanmakuAiRecommendedSwitch'},
    {'1': 'player_danmaku_ai_recommended_level', '3': 5, '4': 1, '5': 5, '10': 'playerDanmakuAiRecommendedLevel'},
    {'1': 'player_danmaku_blocktop', '3': 6, '4': 1, '5': 8, '10': 'playerDanmakuBlocktop'},
    {'1': 'player_danmaku_blockscroll', '3': 7, '4': 1, '5': 8, '10': 'playerDanmakuBlockscroll'},
    {'1': 'player_danmaku_blockbottom', '3': 8, '4': 1, '5': 8, '10': 'playerDanmakuBlockbottom'},
    {'1': 'player_danmaku_blockcolorful', '3': 9, '4': 1, '5': 8, '10': 'playerDanmakuBlockcolorful'},
    {'1': 'player_danmaku_blockrepeat', '3': 10, '4': 1, '5': 8, '10': 'playerDanmakuBlockrepeat'},
    {'1': 'player_danmaku_blockspecial', '3': 11, '4': 1, '5': 8, '10': 'playerDanmakuBlockspecial'},
    {'1': 'player_danmaku_opacity', '3': 12, '4': 1, '5': 2, '10': 'playerDanmakuOpacity'},
    {'1': 'player_danmaku_scalingfactor', '3': 13, '4': 1, '5': 2, '10': 'playerDanmakuScalingfactor'},
    {'1': 'player_danmaku_domain', '3': 14, '4': 1, '5': 2, '10': 'playerDanmakuDomain'},
    {'1': 'player_danmaku_speed', '3': 15, '4': 1, '5': 5, '10': 'playerDanmakuSpeed'},
    {'1': 'inline_player_danmaku_switch', '3': 16, '4': 1, '5': 8, '10': 'inlinePlayerDanmakuSwitch'},
    {'1': 'player_danmaku_senior_mode_switch', '3': 17, '4': 1, '5': 5, '10': 'playerDanmakuSeniorModeSwitch'},
    {'1': 'player_danmaku_ai_recommended_level_v2', '3': 18, '4': 1, '5': 5, '10': 'playerDanmakuAiRecommendedLevelV2'},
    {'1': 'player_danmaku_ai_recommended_level_v2_map', '3': 19, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuDefaultPlayerConfig.PlayerDanmakuAiRecommendedLevelV2MapEntry', '10': 'playerDanmakuAiRecommendedLevelV2Map'},
  ],
  '3': [DanmuDefaultPlayerConfig_PlayerDanmakuAiRecommendedLevelV2MapEntry$json],
};

@$core.Deprecated('Use danmuDefaultPlayerConfigDescriptor instead')
const DanmuDefaultPlayerConfig_PlayerDanmakuAiRecommendedLevelV2MapEntry$json = {
  '1': 'PlayerDanmakuAiRecommendedLevelV2MapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DanmuDefaultPlayerConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmuDefaultPlayerConfigDescriptor = $convert.base64Decode(
    'ChhEYW5tdURlZmF1bHRQbGF5ZXJDb25maWcSSAohcGxheWVyX2Rhbm1ha3VfdXNlX2RlZmF1bH'
    'RfY29uZmlnGAEgASgIUh1wbGF5ZXJEYW5tYWt1VXNlRGVmYXVsdENvbmZpZxJOCiRwbGF5ZXJf'
    'ZGFubWFrdV9haV9yZWNvbW1lbmRlZF9zd2l0Y2gYBCABKAhSIHBsYXllckRhbm1ha3VBaVJlY2'
    '9tbWVuZGVkU3dpdGNoEkwKI3BsYXllcl9kYW5tYWt1X2FpX3JlY29tbWVuZGVkX2xldmVsGAUg'
    'ASgFUh9wbGF5ZXJEYW5tYWt1QWlSZWNvbW1lbmRlZExldmVsEjYKF3BsYXllcl9kYW5tYWt1X2'
    'Jsb2NrdG9wGAYgASgIUhVwbGF5ZXJEYW5tYWt1QmxvY2t0b3ASPAoacGxheWVyX2Rhbm1ha3Vf'
    'YmxvY2tzY3JvbGwYByABKAhSGHBsYXllckRhbm1ha3VCbG9ja3Njcm9sbBI8ChpwbGF5ZXJfZG'
    'FubWFrdV9ibG9ja2JvdHRvbRgIIAEoCFIYcGxheWVyRGFubWFrdUJsb2NrYm90dG9tEkAKHHBs'
    'YXllcl9kYW5tYWt1X2Jsb2NrY29sb3JmdWwYCSABKAhSGnBsYXllckRhbm1ha3VCbG9ja2NvbG'
    '9yZnVsEjwKGnBsYXllcl9kYW5tYWt1X2Jsb2NrcmVwZWF0GAogASgIUhhwbGF5ZXJEYW5tYWt1'
    'QmxvY2tyZXBlYXQSPgobcGxheWVyX2Rhbm1ha3VfYmxvY2tzcGVjaWFsGAsgASgIUhlwbGF5ZX'
    'JEYW5tYWt1QmxvY2tzcGVjaWFsEjQKFnBsYXllcl9kYW5tYWt1X29wYWNpdHkYDCABKAJSFHBs'
    'YXllckRhbm1ha3VPcGFjaXR5EkAKHHBsYXllcl9kYW5tYWt1X3NjYWxpbmdmYWN0b3IYDSABKA'
    'JSGnBsYXllckRhbm1ha3VTY2FsaW5nZmFjdG9yEjIKFXBsYXllcl9kYW5tYWt1X2RvbWFpbhgO'
    'IAEoAlITcGxheWVyRGFubWFrdURvbWFpbhIwChRwbGF5ZXJfZGFubWFrdV9zcGVlZBgPIAEoBV'
    'IScGxheWVyRGFubWFrdVNwZWVkEj8KHGlubGluZV9wbGF5ZXJfZGFubWFrdV9zd2l0Y2gYECAB'
    'KAhSGWlubGluZVBsYXllckRhbm1ha3VTd2l0Y2gSSAohcGxheWVyX2Rhbm1ha3Vfc2VuaW9yX2'
    '1vZGVfc3dpdGNoGBEgASgFUh1wbGF5ZXJEYW5tYWt1U2VuaW9yTW9kZVN3aXRjaBJRCiZwbGF5'
    'ZXJfZGFubWFrdV9haV9yZWNvbW1lbmRlZF9sZXZlbF92MhgSIAEoBVIhcGxheWVyRGFubWFrdU'
    'FpUmVjb21tZW5kZWRMZXZlbFYyEr4BCipwbGF5ZXJfZGFubWFrdV9haV9yZWNvbW1lbmRlZF9s'
    'ZXZlbF92Ml9tYXAYEyADKAsyZC5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5EYW'
    '5tdURlZmF1bHRQbGF5ZXJDb25maWcuUGxheWVyRGFubWFrdUFpUmVjb21tZW5kZWRMZXZlbFYy'
    'TWFwRW50cnlSJHBsYXllckRhbm1ha3VBaVJlY29tbWVuZGVkTGV2ZWxWMk1hcBpXCilQbGF5ZX'
    'JEYW5tYWt1QWlSZWNvbW1lbmRlZExldmVsVjJNYXBFbnRyeRIQCgNrZXkYASABKAVSA2tleRIU'
    'CgV2YWx1ZRgCIAEoBVIFdmFsdWU6AjgB');

@$core.Deprecated('Use danmuPlayerConfigDescriptor instead')
const DanmuPlayerConfig$json = {
  '1': 'DanmuPlayerConfig',
  '2': [
    {'1': 'player_danmaku_switch', '3': 1, '4': 1, '5': 8, '10': 'playerDanmakuSwitch'},
    {'1': 'player_danmaku_switch_save', '3': 2, '4': 1, '5': 8, '10': 'playerDanmakuSwitchSave'},
    {'1': 'player_danmaku_use_default_config', '3': 3, '4': 1, '5': 8, '10': 'playerDanmakuUseDefaultConfig'},
    {'1': 'player_danmaku_ai_recommended_switch', '3': 4, '4': 1, '5': 8, '10': 'playerDanmakuAiRecommendedSwitch'},
    {'1': 'player_danmaku_ai_recommended_level', '3': 5, '4': 1, '5': 5, '10': 'playerDanmakuAiRecommendedLevel'},
    {'1': 'player_danmaku_blocktop', '3': 6, '4': 1, '5': 8, '10': 'playerDanmakuBlocktop'},
    {'1': 'player_danmaku_blockscroll', '3': 7, '4': 1, '5': 8, '10': 'playerDanmakuBlockscroll'},
    {'1': 'player_danmaku_blockbottom', '3': 8, '4': 1, '5': 8, '10': 'playerDanmakuBlockbottom'},
    {'1': 'player_danmaku_blockcolorful', '3': 9, '4': 1, '5': 8, '10': 'playerDanmakuBlockcolorful'},
    {'1': 'player_danmaku_blockrepeat', '3': 10, '4': 1, '5': 8, '10': 'playerDanmakuBlockrepeat'},
    {'1': 'player_danmaku_blockspecial', '3': 11, '4': 1, '5': 8, '10': 'playerDanmakuBlockspecial'},
    {'1': 'player_danmaku_opacity', '3': 12, '4': 1, '5': 2, '10': 'playerDanmakuOpacity'},
    {'1': 'player_danmaku_scalingfactor', '3': 13, '4': 1, '5': 2, '10': 'playerDanmakuScalingfactor'},
    {'1': 'player_danmaku_domain', '3': 14, '4': 1, '5': 2, '10': 'playerDanmakuDomain'},
    {'1': 'player_danmaku_speed', '3': 15, '4': 1, '5': 5, '10': 'playerDanmakuSpeed'},
    {'1': 'player_danmaku_enableblocklist', '3': 16, '4': 1, '5': 8, '10': 'playerDanmakuEnableblocklist'},
    {'1': 'inline_player_danmaku_switch', '3': 17, '4': 1, '5': 8, '10': 'inlinePlayerDanmakuSwitch'},
    {'1': 'inline_player_danmaku_config', '3': 18, '4': 1, '5': 5, '10': 'inlinePlayerDanmakuConfig'},
    {'1': 'player_danmaku_ios_switch_save', '3': 19, '4': 1, '5': 5, '10': 'playerDanmakuIosSwitchSave'},
    {'1': 'player_danmaku_senior_mode_switch', '3': 20, '4': 1, '5': 5, '10': 'playerDanmakuSeniorModeSwitch'},
    {'1': 'player_danmaku_ai_recommended_level_v2', '3': 21, '4': 1, '5': 5, '10': 'playerDanmakuAiRecommendedLevelV2'},
    {'1': 'player_danmaku_ai_recommended_level_v2_map', '3': 22, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuPlayerConfig.PlayerDanmakuAiRecommendedLevelV2MapEntry', '10': 'playerDanmakuAiRecommendedLevelV2Map'},
  ],
  '3': [DanmuPlayerConfig_PlayerDanmakuAiRecommendedLevelV2MapEntry$json],
};

@$core.Deprecated('Use danmuPlayerConfigDescriptor instead')
const DanmuPlayerConfig_PlayerDanmakuAiRecommendedLevelV2MapEntry$json = {
  '1': 'PlayerDanmakuAiRecommendedLevelV2MapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DanmuPlayerConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmuPlayerConfigDescriptor = $convert.base64Decode(
    'ChFEYW5tdVBsYXllckNvbmZpZxIyChVwbGF5ZXJfZGFubWFrdV9zd2l0Y2gYASABKAhSE3BsYX'
    'llckRhbm1ha3VTd2l0Y2gSOwoacGxheWVyX2Rhbm1ha3Vfc3dpdGNoX3NhdmUYAiABKAhSF3Bs'
    'YXllckRhbm1ha3VTd2l0Y2hTYXZlEkgKIXBsYXllcl9kYW5tYWt1X3VzZV9kZWZhdWx0X2Nvbm'
    'ZpZxgDIAEoCFIdcGxheWVyRGFubWFrdVVzZURlZmF1bHRDb25maWcSTgokcGxheWVyX2Rhbm1h'
    'a3VfYWlfcmVjb21tZW5kZWRfc3dpdGNoGAQgASgIUiBwbGF5ZXJEYW5tYWt1QWlSZWNvbW1lbm'
    'RlZFN3aXRjaBJMCiNwbGF5ZXJfZGFubWFrdV9haV9yZWNvbW1lbmRlZF9sZXZlbBgFIAEoBVIf'
    'cGxheWVyRGFubWFrdUFpUmVjb21tZW5kZWRMZXZlbBI2ChdwbGF5ZXJfZGFubWFrdV9ibG9ja3'
    'RvcBgGIAEoCFIVcGxheWVyRGFubWFrdUJsb2NrdG9wEjwKGnBsYXllcl9kYW5tYWt1X2Jsb2Nr'
    'c2Nyb2xsGAcgASgIUhhwbGF5ZXJEYW5tYWt1QmxvY2tzY3JvbGwSPAoacGxheWVyX2Rhbm1ha3'
    'VfYmxvY2tib3R0b20YCCABKAhSGHBsYXllckRhbm1ha3VCbG9ja2JvdHRvbRJAChxwbGF5ZXJf'
    'ZGFubWFrdV9ibG9ja2NvbG9yZnVsGAkgASgIUhpwbGF5ZXJEYW5tYWt1QmxvY2tjb2xvcmZ1bB'
    'I8ChpwbGF5ZXJfZGFubWFrdV9ibG9ja3JlcGVhdBgKIAEoCFIYcGxheWVyRGFubWFrdUJsb2Nr'
    'cmVwZWF0Ej4KG3BsYXllcl9kYW5tYWt1X2Jsb2Nrc3BlY2lhbBgLIAEoCFIZcGxheWVyRGFubW'
    'FrdUJsb2Nrc3BlY2lhbBI0ChZwbGF5ZXJfZGFubWFrdV9vcGFjaXR5GAwgASgCUhRwbGF5ZXJE'
    'YW5tYWt1T3BhY2l0eRJAChxwbGF5ZXJfZGFubWFrdV9zY2FsaW5nZmFjdG9yGA0gASgCUhpwbG'
    'F5ZXJEYW5tYWt1U2NhbGluZ2ZhY3RvchIyChVwbGF5ZXJfZGFubWFrdV9kb21haW4YDiABKAJS'
    'E3BsYXllckRhbm1ha3VEb21haW4SMAoUcGxheWVyX2Rhbm1ha3Vfc3BlZWQYDyABKAVSEnBsYX'
    'llckRhbm1ha3VTcGVlZBJECh5wbGF5ZXJfZGFubWFrdV9lbmFibGVibG9ja2xpc3QYECABKAhS'
    'HHBsYXllckRhbm1ha3VFbmFibGVibG9ja2xpc3QSPwocaW5saW5lX3BsYXllcl9kYW5tYWt1X3'
    'N3aXRjaBgRIAEoCFIZaW5saW5lUGxheWVyRGFubWFrdVN3aXRjaBI/ChxpbmxpbmVfcGxheWVy'
    'X2Rhbm1ha3VfY29uZmlnGBIgASgFUhlpbmxpbmVQbGF5ZXJEYW5tYWt1Q29uZmlnEkIKHnBsYX'
    'llcl9kYW5tYWt1X2lvc19zd2l0Y2hfc2F2ZRgTIAEoBVIacGxheWVyRGFubWFrdUlvc1N3aXRj'
    'aFNhdmUSSAohcGxheWVyX2Rhbm1ha3Vfc2VuaW9yX21vZGVfc3dpdGNoGBQgASgFUh1wbGF5ZX'
    'JEYW5tYWt1U2VuaW9yTW9kZVN3aXRjaBJRCiZwbGF5ZXJfZGFubWFrdV9haV9yZWNvbW1lbmRl'
    'ZF9sZXZlbF92MhgVIAEoBVIhcGxheWVyRGFubWFrdUFpUmVjb21tZW5kZWRMZXZlbFYyErcBCi'
    'pwbGF5ZXJfZGFubWFrdV9haV9yZWNvbW1lbmRlZF9sZXZlbF92Ml9tYXAYFiADKAsyXS5iaWxp'
    'YmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5EYW5tdVBsYXllckNvbmZpZy5QbGF5ZXJEYW'
    '5tYWt1QWlSZWNvbW1lbmRlZExldmVsVjJNYXBFbnRyeVIkcGxheWVyRGFubWFrdUFpUmVjb21t'
    'ZW5kZWRMZXZlbFYyTWFwGlcKKVBsYXllckRhbm1ha3VBaVJlY29tbWVuZGVkTGV2ZWxWMk1hcE'
    'VudHJ5EhAKA2tleRgBIAEoBVIDa2V5EhQKBXZhbHVlGAIgASgFUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use danmuPlayerConfigPanelDescriptor instead')
const DanmuPlayerConfigPanel$json = {
  '1': 'DanmuPlayerConfigPanel',
  '2': [
    {'1': 'selection_text', '3': 1, '4': 1, '5': 9, '10': 'selectionText'},
  ],
};

/// Descriptor for `DanmuPlayerConfigPanel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmuPlayerConfigPanelDescriptor = $convert.base64Decode(
    'ChZEYW5tdVBsYXllckNvbmZpZ1BhbmVsEiUKDnNlbGVjdGlvbl90ZXh0GAEgASgJUg1zZWxlY3'
    'Rpb25UZXh0');

@$core.Deprecated('Use danmuPlayerDynamicConfigDescriptor instead')
const DanmuPlayerDynamicConfig$json = {
  '1': 'DanmuPlayerDynamicConfig',
  '2': [
    {'1': 'progress', '3': 1, '4': 1, '5': 5, '10': 'progress'},
    {'1': 'player_danmaku_domain', '3': 14, '4': 1, '5': 2, '10': 'playerDanmakuDomain'},
  ],
};

/// Descriptor for `DanmuPlayerDynamicConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmuPlayerDynamicConfigDescriptor = $convert.base64Decode(
    'ChhEYW5tdVBsYXllckR5bmFtaWNDb25maWcSGgoIcHJvZ3Jlc3MYASABKAVSCHByb2dyZXNzEj'
    'IKFXBsYXllcl9kYW5tYWt1X2RvbWFpbhgOIAEoAlITcGxheWVyRGFubWFrdURvbWFpbg==');

@$core.Deprecated('Use danmuPlayerViewConfigDescriptor instead')
const DanmuPlayerViewConfig$json = {
  '1': 'DanmuPlayerViewConfig',
  '2': [
    {'1': 'danmuku_default_player_config', '3': 1, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuDefaultPlayerConfig', '10': 'danmukuDefaultPlayerConfig'},
    {'1': 'danmuku_player_config', '3': 2, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuPlayerConfig', '10': 'danmukuPlayerConfig'},
    {'1': 'danmuku_player_dynamic_config', '3': 3, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuPlayerDynamicConfig', '10': 'danmukuPlayerDynamicConfig'},
    {'1': 'danmuku_player_config_panel', '3': 4, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuPlayerConfigPanel', '10': 'danmukuPlayerConfigPanel'},
  ],
};

/// Descriptor for `DanmuPlayerViewConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmuPlayerViewConfigDescriptor = $convert.base64Decode(
    'ChVEYW5tdVBsYXllclZpZXdDb25maWcSfQodZGFubXVrdV9kZWZhdWx0X3BsYXllcl9jb25maW'
    'cYASABKAsyOi5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5EYW5tdURlZmF1bHRQ'
    'bGF5ZXJDb25maWdSGmRhbm11a3VEZWZhdWx0UGxheWVyQ29uZmlnEmcKFWRhbm11a3VfcGxheW'
    'VyX2NvbmZpZxgCIAEoCzIzLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLkRhbm11'
    'UGxheWVyQ29uZmlnUhNkYW5tdWt1UGxheWVyQ29uZmlnEn0KHWRhbm11a3VfcGxheWVyX2R5bm'
    'FtaWNfY29uZmlnGAMgAygLMjouYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuRGFu'
    'bXVQbGF5ZXJEeW5hbWljQ29uZmlnUhpkYW5tdWt1UGxheWVyRHluYW1pY0NvbmZpZxJ3ChtkYW'
    '5tdWt1X3BsYXllcl9jb25maWdfcGFuZWwYBCABKAsyOC5iaWxpYmlsaS5jb21tdW5pdHkuc2Vy'
    'dmljZS5kbS52MS5EYW5tdVBsYXllckNvbmZpZ1BhbmVsUhhkYW5tdWt1UGxheWVyQ29uZmlnUG'
    'FuZWw=');

@$core.Deprecated('Use danmuWebPlayerConfigDescriptor instead')
const DanmuWebPlayerConfig$json = {
  '1': 'DanmuWebPlayerConfig',
  '2': [
    {'1': 'dm_switch', '3': 1, '4': 1, '5': 8, '10': 'dmSwitch'},
    {'1': 'ai_switch', '3': 2, '4': 1, '5': 8, '10': 'aiSwitch'},
    {'1': 'ai_level', '3': 3, '4': 1, '5': 5, '10': 'aiLevel'},
    {'1': 'blocktop', '3': 4, '4': 1, '5': 8, '10': 'blocktop'},
    {'1': 'blockscroll', '3': 5, '4': 1, '5': 8, '10': 'blockscroll'},
    {'1': 'blockbottom', '3': 6, '4': 1, '5': 8, '10': 'blockbottom'},
    {'1': 'blockcolor', '3': 7, '4': 1, '5': 8, '10': 'blockcolor'},
    {'1': 'blockspecial', '3': 8, '4': 1, '5': 8, '10': 'blockspecial'},
    {'1': 'preventshade', '3': 9, '4': 1, '5': 8, '10': 'preventshade'},
    {'1': 'dmask', '3': 10, '4': 1, '5': 8, '10': 'dmask'},
    {'1': 'opacity', '3': 11, '4': 1, '5': 2, '10': 'opacity'},
    {'1': 'dmarea', '3': 12, '4': 1, '5': 5, '10': 'dmarea'},
    {'1': 'speedplus', '3': 13, '4': 1, '5': 2, '10': 'speedplus'},
    {'1': 'fontsize', '3': 14, '4': 1, '5': 2, '10': 'fontsize'},
    {'1': 'screensync', '3': 15, '4': 1, '5': 8, '10': 'screensync'},
    {'1': 'speedsync', '3': 16, '4': 1, '5': 8, '10': 'speedsync'},
    {'1': 'fontfamily', '3': 17, '4': 1, '5': 9, '10': 'fontfamily'},
    {'1': 'bold', '3': 18, '4': 1, '5': 8, '10': 'bold'},
    {'1': 'fontborder', '3': 19, '4': 1, '5': 5, '10': 'fontborder'},
    {'1': 'draw_type', '3': 20, '4': 1, '5': 9, '10': 'drawType'},
    {'1': 'senior_mode_switch', '3': 21, '4': 1, '5': 5, '10': 'seniorModeSwitch'},
    {'1': 'ai_level_v2', '3': 22, '4': 1, '5': 5, '10': 'aiLevelV2'},
    {'1': 'ai_level_v2_map', '3': 23, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuWebPlayerConfig.AiLevelV2MapEntry', '10': 'aiLevelV2Map'},
  ],
  '3': [DanmuWebPlayerConfig_AiLevelV2MapEntry$json],
};

@$core.Deprecated('Use danmuWebPlayerConfigDescriptor instead')
const DanmuWebPlayerConfig_AiLevelV2MapEntry$json = {
  '1': 'AiLevelV2MapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DanmuWebPlayerConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmuWebPlayerConfigDescriptor = $convert.base64Decode(
    'ChREYW5tdVdlYlBsYXllckNvbmZpZxIbCglkbV9zd2l0Y2gYASABKAhSCGRtU3dpdGNoEhsKCW'
    'FpX3N3aXRjaBgCIAEoCFIIYWlTd2l0Y2gSGQoIYWlfbGV2ZWwYAyABKAVSB2FpTGV2ZWwSGgoI'
    'YmxvY2t0b3AYBCABKAhSCGJsb2NrdG9wEiAKC2Jsb2Nrc2Nyb2xsGAUgASgIUgtibG9ja3Njcm'
    '9sbBIgCgtibG9ja2JvdHRvbRgGIAEoCFILYmxvY2tib3R0b20SHgoKYmxvY2tjb2xvchgHIAEo'
    'CFIKYmxvY2tjb2xvchIiCgxibG9ja3NwZWNpYWwYCCABKAhSDGJsb2Nrc3BlY2lhbBIiCgxwcm'
    'V2ZW50c2hhZGUYCSABKAhSDHByZXZlbnRzaGFkZRIUCgVkbWFzaxgKIAEoCFIFZG1hc2sSGAoH'
    'b3BhY2l0eRgLIAEoAlIHb3BhY2l0eRIWCgZkbWFyZWEYDCABKAVSBmRtYXJlYRIcCglzcGVlZH'
    'BsdXMYDSABKAJSCXNwZWVkcGx1cxIaCghmb250c2l6ZRgOIAEoAlIIZm9udHNpemUSHgoKc2Ny'
    'ZWVuc3luYxgPIAEoCFIKc2NyZWVuc3luYxIcCglzcGVlZHN5bmMYECABKAhSCXNwZWVkc3luYx'
    'IeCgpmb250ZmFtaWx5GBEgASgJUgpmb250ZmFtaWx5EhIKBGJvbGQYEiABKAhSBGJvbGQSHgoK'
    'Zm9udGJvcmRlchgTIAEoBVIKZm9udGJvcmRlchIbCglkcmF3X3R5cGUYFCABKAlSCGRyYXdUeX'
    'BlEiwKEnNlbmlvcl9tb2RlX3N3aXRjaBgVIAEoBVIQc2VuaW9yTW9kZVN3aXRjaBIeCgthaV9s'
    'ZXZlbF92MhgWIAEoBVIJYWlMZXZlbFYyEm8KD2FpX2xldmVsX3YyX21hcBgXIAMoCzJILmJpbG'
    'liaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLkRhbm11V2ViUGxheWVyQ29uZmlnLkFpTGV2'
    'ZWxWMk1hcEVudHJ5UgxhaUxldmVsVjJNYXAaPwoRQWlMZXZlbFYyTWFwRW50cnkSEAoDa2V5GA'
    'EgASgFUgNrZXkSFAoFdmFsdWUYAiABKAVSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use dmColorfulDescriptor instead')
const DmColorful$json = {
  '1': 'DmColorful',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.DmColorfulType', '10': 'type'},
    {'1': 'src', '3': 2, '4': 1, '5': 9, '10': 'src'},
  ],
};

/// Descriptor for `DmColorful`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmColorfulDescriptor = $convert.base64Decode(
    'CgpEbUNvbG9yZnVsEkQKBHR5cGUYASABKA4yMC5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS'
    '5kbS52MS5EbUNvbG9yZnVsVHlwZVIEdHlwZRIQCgNzcmMYAiABKAlSA3NyYw==');

@$core.Deprecated('Use dmExpoReportReqDescriptor instead')
const DmExpoReportReq$json = {
  '1': 'DmExpoReportReq',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
  ],
};

/// Descriptor for `DmExpoReportReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmExpoReportReqDescriptor = $convert.base64Decode(
    'Cg9EbUV4cG9SZXBvcnRSZXESHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhAKA29pZB'
    'gCIAEoA1IDb2lkEhQKBXNwbWlkGAQgASgJUgVzcG1pZA==');

@$core.Deprecated('Use dmExpoReportResDescriptor instead')
const DmExpoReportRes$json = {
  '1': 'DmExpoReportRes',
};

/// Descriptor for `DmExpoReportRes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmExpoReportResDescriptor = $convert.base64Decode(
    'Cg9EbUV4cG9SZXBvcnRSZXM=');

@$core.Deprecated('Use dmPlayerConfigReqDescriptor instead')
const DmPlayerConfigReq$json = {
  '1': 'DmPlayerConfigReq',
  '2': [
    {'1': 'ts', '3': 1, '4': 1, '5': 3, '10': 'ts'},
    {'1': 'switch', '3': 2, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuSwitch', '10': 'switch'},
    {'1': 'switch_save', '3': 3, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuSwitchSave', '10': 'switchSave'},
    {'1': 'use_default_config', '3': 4, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuUseDefaultConfig', '10': 'useDefaultConfig'},
    {'1': 'ai_recommended_switch', '3': 5, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuAiRecommendedSwitch', '10': 'aiRecommendedSwitch'},
    {'1': 'ai_recommended_level', '3': 6, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuAiRecommendedLevel', '10': 'aiRecommendedLevel'},
    {'1': 'blocktop', '3': 7, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuBlocktop', '10': 'blocktop'},
    {'1': 'blockscroll', '3': 8, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuBlockscroll', '10': 'blockscroll'},
    {'1': 'blockbottom', '3': 9, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuBlockbottom', '10': 'blockbottom'},
    {'1': 'blockcolorful', '3': 10, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuBlockcolorful', '10': 'blockcolorful'},
    {'1': 'blockrepeat', '3': 11, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuBlockrepeat', '10': 'blockrepeat'},
    {'1': 'blockspecial', '3': 12, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuBlockspecial', '10': 'blockspecial'},
    {'1': 'opacity', '3': 13, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuOpacity', '10': 'opacity'},
    {'1': 'scalingfactor', '3': 14, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuScalingfactor', '10': 'scalingfactor'},
    {'1': 'domain', '3': 15, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuDomain', '10': 'domain'},
    {'1': 'speed', '3': 16, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuSpeed', '10': 'speed'},
    {'1': 'enableblocklist', '3': 17, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuEnableblocklist', '10': 'enableblocklist'},
    {'1': 'inlinePlayerDanmakuSwitch', '3': 18, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.InlinePlayerDanmakuSwitch', '10': 'inlinePlayerDanmakuSwitch'},
    {'1': 'senior_mode_switch', '3': 19, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuSeniorModeSwitch', '10': 'seniorModeSwitch'},
    {'1': 'ai_recommended_level_v2', '3': 20, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.PlayerDanmakuAiRecommendedLevelV2', '10': 'aiRecommendedLevelV2'},
  ],
};

/// Descriptor for `DmPlayerConfigReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmPlayerConfigReqDescriptor = $convert.base64Decode(
    'ChFEbVBsYXllckNvbmZpZ1JlcRIOCgJ0cxgBIAEoA1ICdHMSTQoGc3dpdGNoGAIgASgLMjUuYm'
    'lsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuUGxheWVyRGFubWFrdVN3aXRjaFIGc3dp'
    'dGNoEloKC3N3aXRjaF9zYXZlGAMgASgLMjkuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG'
    '0udjEuUGxheWVyRGFubWFrdVN3aXRjaFNhdmVSCnN3aXRjaFNhdmUSbQoSdXNlX2RlZmF1bHRf'
    'Y29uZmlnGAQgASgLMj8uYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuUGxheWVyRG'
    'FubWFrdVVzZURlZmF1bHRDb25maWdSEHVzZURlZmF1bHRDb25maWcSdgoVYWlfcmVjb21tZW5k'
    'ZWRfc3dpdGNoGAUgASgLMkIuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuUGxheW'
    'VyRGFubWFrdUFpUmVjb21tZW5kZWRTd2l0Y2hSE2FpUmVjb21tZW5kZWRTd2l0Y2gScwoUYWlf'
    'cmVjb21tZW5kZWRfbGV2ZWwYBiABKAsyQS5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS'
    '52MS5QbGF5ZXJEYW5tYWt1QWlSZWNvbW1lbmRlZExldmVsUhJhaVJlY29tbWVuZGVkTGV2ZWwS'
    'UwoIYmxvY2t0b3AYByABKAsyNy5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5QbG'
    'F5ZXJEYW5tYWt1QmxvY2t0b3BSCGJsb2NrdG9wElwKC2Jsb2Nrc2Nyb2xsGAggASgLMjouYmls'
    'aWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuUGxheWVyRGFubWFrdUJsb2Nrc2Nyb2xsUg'
    'tibG9ja3Njcm9sbBJcCgtibG9ja2JvdHRvbRgJIAEoCzI6LmJpbGliaWxpLmNvbW11bml0eS5z'
    'ZXJ2aWNlLmRtLnYxLlBsYXllckRhbm1ha3VCbG9ja2JvdHRvbVILYmxvY2tib3R0b20SYgoNYm'
    'xvY2tjb2xvcmZ1bBgKIAEoCzI8LmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLlBs'
    'YXllckRhbm1ha3VCbG9ja2NvbG9yZnVsUg1ibG9ja2NvbG9yZnVsElwKC2Jsb2NrcmVwZWF0GA'
    'sgASgLMjouYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuUGxheWVyRGFubWFrdUJs'
    'b2NrcmVwZWF0UgtibG9ja3JlcGVhdBJfCgxibG9ja3NwZWNpYWwYDCABKAsyOy5iaWxpYmlsaS'
    '5jb21tdW5pdHkuc2VydmljZS5kbS52MS5QbGF5ZXJEYW5tYWt1QmxvY2tzcGVjaWFsUgxibG9j'
    'a3NwZWNpYWwSUAoHb3BhY2l0eRgNIAEoCzI2LmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLm'
    'RtLnYxLlBsYXllckRhbm1ha3VPcGFjaXR5UgdvcGFjaXR5EmIKDXNjYWxpbmdmYWN0b3IYDiAB'
    'KAsyPC5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5QbGF5ZXJEYW5tYWt1U2NhbG'
    'luZ2ZhY3RvclINc2NhbGluZ2ZhY3RvchJNCgZkb21haW4YDyABKAsyNS5iaWxpYmlsaS5jb21t'
    'dW5pdHkuc2VydmljZS5kbS52MS5QbGF5ZXJEYW5tYWt1RG9tYWluUgZkb21haW4SSgoFc3BlZW'
    'QYECABKAsyNC5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5QbGF5ZXJEYW5tYWt1'
    'U3BlZWRSBXNwZWVkEmgKD2VuYWJsZWJsb2NrbGlzdBgRIAEoCzI+LmJpbGliaWxpLmNvbW11bm'
    'l0eS5zZXJ2aWNlLmRtLnYxLlBsYXllckRhbm1ha3VFbmFibGVibG9ja2xpc3RSD2VuYWJsZWJs'
    'b2NrbGlzdBJ5ChlpbmxpbmVQbGF5ZXJEYW5tYWt1U3dpdGNoGBIgASgLMjsuYmlsaWJpbGkuY2'
    '9tbXVuaXR5LnNlcnZpY2UuZG0udjEuSW5saW5lUGxheWVyRGFubWFrdVN3aXRjaFIZaW5saW5l'
    'UGxheWVyRGFubWFrdVN3aXRjaBJtChJzZW5pb3JfbW9kZV9zd2l0Y2gYEyABKAsyPy5iaWxpYm'
    'lsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5QbGF5ZXJEYW5tYWt1U2VuaW9yTW9kZVN3aXRj'
    'aFIQc2VuaW9yTW9kZVN3aXRjaBJ6ChdhaV9yZWNvbW1lbmRlZF9sZXZlbF92MhgUIAEoCzJDLm'
    'JpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLlBsYXllckRhbm1ha3VBaVJlY29tbWVu'
    'ZGVkTGV2ZWxWMlIUYWlSZWNvbW1lbmRlZExldmVsVjI=');

@$core.Deprecated('Use dmSegConfigDescriptor instead')
const DmSegConfig$json = {
  '1': 'DmSegConfig',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 3, '10': 'pageSize'},
    {'1': 'total', '3': 2, '4': 1, '5': 3, '10': 'total'},
  ],
};

/// Descriptor for `DmSegConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegConfigDescriptor = $convert.base64Decode(
    'CgtEbVNlZ0NvbmZpZxIbCglwYWdlX3NpemUYASABKANSCHBhZ2VTaXplEhQKBXRvdGFsGAIgAS'
    'gDUgV0b3RhbA==');

@$core.Deprecated('Use dmSegMobileReplyDescriptor instead')
const DmSegMobileReply$json = {
  '1': 'DmSegMobileReply',
  '2': [
    {'1': 'elems', '3': 1, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmakuElem', '10': 'elems'},
    {'1': 'state', '3': 2, '4': 1, '5': 5, '10': 'state'},
    {'1': 'ai_flag', '3': 3, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmakuAIFlag', '10': 'aiFlag'},
    {'1': 'colorfulSrc', '3': 5, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DmColorful', '10': 'colorfulSrc'},
  ],
};

/// Descriptor for `DmSegMobileReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegMobileReplyDescriptor = $convert.base64Decode(
    'ChBEbVNlZ01vYmlsZVJlcGx5EkMKBWVsZW1zGAEgAygLMi0uYmlsaWJpbGkuY29tbXVuaXR5Ln'
    'NlcnZpY2UuZG0udjEuRGFubWFrdUVsZW1SBWVsZW1zEhQKBXN0YXRlGAIgASgFUgVzdGF0ZRJI'
    'CgdhaV9mbGFnGAMgASgLMi8uYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuRGFubW'
    'FrdUFJRmxhZ1IGYWlGbGFnEk4KC2NvbG9yZnVsU3JjGAUgAygLMiwuYmlsaWJpbGkuY29tbXVu'
    'aXR5LnNlcnZpY2UuZG0udjEuRG1Db2xvcmZ1bFILY29sb3JmdWxTcmM=');

@$core.Deprecated('Use dmSegMobileReqDescriptor instead')
const DmSegMobileReq$json = {
  '1': 'DmSegMobileReq',
  '2': [
    {'1': 'pid', '3': 1, '4': 1, '5': 3, '10': 'pid'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'type', '3': 3, '4': 1, '5': 5, '10': 'type'},
    {'1': 'segment_index', '3': 4, '4': 1, '5': 3, '10': 'segmentIndex'},
    {'1': 'teenagers_mode', '3': 5, '4': 1, '5': 5, '10': 'teenagersMode'},
    {'1': 'ps', '3': 6, '4': 1, '5': 3, '10': 'ps'},
    {'1': 'pe', '3': 7, '4': 1, '5': 3, '10': 'pe'},
    {'1': 'pull_mode', '3': 8, '4': 1, '5': 5, '10': 'pullMode'},
    {'1': 'from_scene', '3': 9, '4': 1, '5': 5, '10': 'fromScene'},
  ],
};

/// Descriptor for `DmSegMobileReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegMobileReqDescriptor = $convert.base64Decode(
    'Cg5EbVNlZ01vYmlsZVJlcRIQCgNwaWQYASABKANSA3BpZBIQCgNvaWQYAiABKANSA29pZBISCg'
    'R0eXBlGAMgASgFUgR0eXBlEiMKDXNlZ21lbnRfaW5kZXgYBCABKANSDHNlZ21lbnRJbmRleBIl'
    'Cg50ZWVuYWdlcnNfbW9kZRgFIAEoBVINdGVlbmFnZXJzTW9kZRIOCgJwcxgGIAEoA1ICcHMSDg'
    'oCcGUYByABKANSAnBlEhsKCXB1bGxfbW9kZRgIIAEoBVIIcHVsbE1vZGUSHQoKZnJvbV9zY2Vu'
    'ZRgJIAEoBVIJZnJvbVNjZW5l');

@$core.Deprecated('Use dmSegOttReplyDescriptor instead')
const DmSegOttReply$json = {
  '1': 'DmSegOttReply',
  '2': [
    {'1': 'closed', '3': 1, '4': 1, '5': 8, '10': 'closed'},
    {'1': 'elems', '3': 2, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmakuElem', '10': 'elems'},
  ],
};

/// Descriptor for `DmSegOttReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegOttReplyDescriptor = $convert.base64Decode(
    'Cg1EbVNlZ090dFJlcGx5EhYKBmNsb3NlZBgBIAEoCFIGY2xvc2VkEkMKBWVsZW1zGAIgAygLMi'
    '0uYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuRGFubWFrdUVsZW1SBWVsZW1z');

@$core.Deprecated('Use dmSegOttReqDescriptor instead')
const DmSegOttReq$json = {
  '1': 'DmSegOttReq',
  '2': [
    {'1': 'pid', '3': 1, '4': 1, '5': 3, '10': 'pid'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'type', '3': 3, '4': 1, '5': 5, '10': 'type'},
    {'1': 'segment_index', '3': 4, '4': 1, '5': 3, '10': 'segmentIndex'},
  ],
};

/// Descriptor for `DmSegOttReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegOttReqDescriptor = $convert.base64Decode(
    'CgtEbVNlZ090dFJlcRIQCgNwaWQYASABKANSA3BpZBIQCgNvaWQYAiABKANSA29pZBISCgR0eX'
    'BlGAMgASgFUgR0eXBlEiMKDXNlZ21lbnRfaW5kZXgYBCABKANSDHNlZ21lbnRJbmRleA==');

@$core.Deprecated('Use dmSegSDKReplyDescriptor instead')
const DmSegSDKReply$json = {
  '1': 'DmSegSDKReply',
  '2': [
    {'1': 'closed', '3': 1, '4': 1, '5': 8, '10': 'closed'},
    {'1': 'elems', '3': 2, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmakuElem', '10': 'elems'},
  ],
};

/// Descriptor for `DmSegSDKReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegSDKReplyDescriptor = $convert.base64Decode(
    'Cg1EbVNlZ1NES1JlcGx5EhYKBmNsb3NlZBgBIAEoCFIGY2xvc2VkEkMKBWVsZW1zGAIgAygLMi'
    '0uYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuRGFubWFrdUVsZW1SBWVsZW1z');

@$core.Deprecated('Use dmSegSDKReqDescriptor instead')
const DmSegSDKReq$json = {
  '1': 'DmSegSDKReq',
  '2': [
    {'1': 'pid', '3': 1, '4': 1, '5': 3, '10': 'pid'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'type', '3': 3, '4': 1, '5': 5, '10': 'type'},
    {'1': 'segment_index', '3': 4, '4': 1, '5': 3, '10': 'segmentIndex'},
  ],
};

/// Descriptor for `DmSegSDKReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegSDKReqDescriptor = $convert.base64Decode(
    'CgtEbVNlZ1NES1JlcRIQCgNwaWQYASABKANSA3BpZBIQCgNvaWQYAiABKANSA29pZBISCgR0eX'
    'BlGAMgASgFUgR0eXBlEiMKDXNlZ21lbnRfaW5kZXgYBCABKANSDHNlZ21lbnRJbmRleA==');

@$core.Deprecated('Use dmViewReplyDescriptor instead')
const DmViewReply$json = {
  '1': 'DmViewReply',
  '2': [
    {'1': 'closed', '3': 1, '4': 1, '5': 8, '10': 'closed'},
    {'1': 'mask', '3': 2, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.VideoMask', '10': 'mask'},
    {'1': 'subtitle', '3': 3, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.VideoSubtitle', '10': 'subtitle'},
    {'1': 'special_dms', '3': 4, '4': 3, '5': 9, '10': 'specialDms'},
    {'1': 'ai_flag', '3': 5, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmakuFlagConfig', '10': 'aiFlag'},
    {'1': 'player_config', '3': 6, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuPlayerViewConfig', '10': 'playerConfig'},
    {'1': 'send_box_style', '3': 7, '4': 1, '5': 5, '10': 'sendBoxStyle'},
    {'1': 'allow', '3': 8, '4': 1, '5': 8, '10': 'allow'},
    {'1': 'check_box', '3': 9, '4': 1, '5': 9, '10': 'checkBox'},
    {'1': 'check_box_show_msg', '3': 10, '4': 1, '5': 9, '10': 'checkBoxShowMsg'},
    {'1': 'text_placeholder', '3': 11, '4': 1, '5': 9, '10': 'textPlaceholder'},
    {'1': 'input_placeholder', '3': 12, '4': 1, '5': 9, '10': 'inputPlaceholder'},
    {'1': 'report_filter_content', '3': 13, '4': 3, '5': 9, '10': 'reportFilterContent'},
    {'1': 'expo_report', '3': 14, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.ExpoReport', '10': 'expoReport'},
    {'1': 'buzzword_config', '3': 15, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.BuzzwordConfig', '10': 'buzzwordConfig'},
    {'1': 'expressions', '3': 16, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.Expressions', '10': 'expressions'},
    {'1': 'post_panel', '3': 17, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.PostPanel', '10': 'postPanel'},
    {'1': 'activity_meta', '3': 18, '4': 3, '5': 9, '10': 'activityMeta'},
    {'1': 'post_panel2', '3': 19, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.PostPanelV2', '10': 'postPanel2'},
  ],
};

/// Descriptor for `DmViewReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmViewReplyDescriptor = $convert.base64Decode(
    'CgtEbVZpZXdSZXBseRIWCgZjbG9zZWQYASABKAhSBmNsb3NlZBI/CgRtYXNrGAIgASgLMisuYm'
    'lsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuVmlkZW9NYXNrUgRtYXNrEksKCHN1YnRp'
    'dGxlGAMgASgLMi8uYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuVmlkZW9TdWJ0aX'
    'RsZVIIc3VidGl0bGUSHwoLc3BlY2lhbF9kbXMYBCADKAlSCnNwZWNpYWxEbXMSTAoHYWlfZmxh'
    'ZxgFIAEoCzIzLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLkRhbm1ha3VGbGFnQ2'
    '9uZmlnUgZhaUZsYWcSXAoNcGxheWVyX2NvbmZpZxgGIAEoCzI3LmJpbGliaWxpLmNvbW11bml0'
    'eS5zZXJ2aWNlLmRtLnYxLkRhbm11UGxheWVyVmlld0NvbmZpZ1IMcGxheWVyQ29uZmlnEiQKDn'
    'NlbmRfYm94X3N0eWxlGAcgASgFUgxzZW5kQm94U3R5bGUSFAoFYWxsb3cYCCABKAhSBWFsbG93'
    'EhsKCWNoZWNrX2JveBgJIAEoCVIIY2hlY2tCb3gSKwoSY2hlY2tfYm94X3Nob3dfbXNnGAogAS'
    'gJUg9jaGVja0JveFNob3dNc2cSKQoQdGV4dF9wbGFjZWhvbGRlchgLIAEoCVIPdGV4dFBsYWNl'
    'aG9sZGVyEisKEWlucHV0X3BsYWNlaG9sZGVyGAwgASgJUhBpbnB1dFBsYWNlaG9sZGVyEjIKFX'
    'JlcG9ydF9maWx0ZXJfY29udGVudBgNIAMoCVITcmVwb3J0RmlsdGVyQ29udGVudBJNCgtleHBv'
    'X3JlcG9ydBgOIAEoCzIsLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLkV4cG9SZX'
    'BvcnRSCmV4cG9SZXBvcnQSWQoPYnV6endvcmRfY29uZmlnGA8gASgLMjAuYmlsaWJpbGkuY29t'
    'bXVuaXR5LnNlcnZpY2UuZG0udjEuQnV6endvcmRDb25maWdSDmJ1enp3b3JkQ29uZmlnEk8KC2'
    'V4cHJlc3Npb25zGBAgAygLMi0uYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuRXhw'
    'cmVzc2lvbnNSC2V4cHJlc3Npb25zEkoKCnBvc3RfcGFuZWwYESADKAsyKy5iaWxpYmlsaS5jb2'
    '1tdW5pdHkuc2VydmljZS5kbS52MS5Qb3N0UGFuZWxSCXBvc3RQYW5lbBIjCg1hY3Rpdml0eV9t'
    'ZXRhGBIgAygJUgxhY3Rpdml0eU1ldGESTgoLcG9zdF9wYW5lbDIYEyADKAsyLS5iaWxpYmlsaS'
    '5jb21tdW5pdHkuc2VydmljZS5kbS52MS5Qb3N0UGFuZWxWMlIKcG9zdFBhbmVsMg==');

@$core.Deprecated('Use dmViewReqDescriptor instead')
const DmViewReq$json = {
  '1': 'DmViewReq',
  '2': [
    {'1': 'pid', '3': 1, '4': 1, '5': 3, '10': 'pid'},
    {'1': 'oid', '3': 2, '4': 1, '5': 3, '10': 'oid'},
    {'1': 'type', '3': 3, '4': 1, '5': 5, '10': 'type'},
    {'1': 'spmid', '3': 4, '4': 1, '5': 9, '10': 'spmid'},
    {'1': 'is_hard_boot', '3': 5, '4': 1, '5': 5, '10': 'isHardBoot'},
  ],
};

/// Descriptor for `DmViewReq`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmViewReqDescriptor = $convert.base64Decode(
    'CglEbVZpZXdSZXESEAoDcGlkGAEgASgDUgNwaWQSEAoDb2lkGAIgASgDUgNvaWQSEgoEdHlwZR'
    'gDIAEoBVIEdHlwZRIUCgVzcG1pZBgEIAEoCVIFc3BtaWQSIAoMaXNfaGFyZF9ib290GAUgASgF'
    'Ugppc0hhcmRCb290');

@$core.Deprecated('Use dmWebViewReplyDescriptor instead')
const DmWebViewReply$json = {
  '1': 'DmWebViewReply',
  '2': [
    {'1': 'state', '3': 1, '4': 1, '5': 5, '10': 'state'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'text_side', '3': 3, '4': 1, '5': 9, '10': 'textSide'},
    {'1': 'dm_sge', '3': 4, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DmSegConfig', '10': 'dmSge'},
    {'1': 'flag', '3': 5, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmakuFlagConfig', '10': 'flag'},
    {'1': 'special_dms', '3': 6, '4': 3, '5': 9, '10': 'specialDms'},
    {'1': 'check_box', '3': 7, '4': 1, '5': 8, '10': 'checkBox'},
    {'1': 'count', '3': 8, '4': 1, '5': 3, '10': 'count'},
    {'1': 'commandDms', '3': 9, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.CommandDm', '10': 'commandDms'},
    {'1': 'player_config', '3': 10, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.DanmuWebPlayerConfig', '10': 'playerConfig'},
    {'1': 'report_filter_content', '3': 11, '4': 3, '5': 9, '10': 'reportFilterContent'},
    {'1': 'expressions', '3': 12, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.Expressions', '10': 'expressions'},
    {'1': 'post_panel', '3': 13, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.PostPanel', '10': 'postPanel'},
    {'1': 'activity_meta', '3': 14, '4': 3, '5': 9, '10': 'activityMeta'},
  ],
};

/// Descriptor for `DmWebViewReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmWebViewReplyDescriptor = $convert.base64Decode(
    'Cg5EbVdlYlZpZXdSZXBseRIUCgVzdGF0ZRgBIAEoBVIFc3RhdGUSEgoEdGV4dBgCIAEoCVIEdG'
    'V4dBIbCgl0ZXh0X3NpZGUYAyABKAlSCHRleHRTaWRlEkQKBmRtX3NnZRgEIAEoCzItLmJpbGli'
    'aWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLkRtU2VnQ29uZmlnUgVkbVNnZRJHCgRmbGFnGA'
    'UgASgLMjMuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuRGFubWFrdUZsYWdDb25m'
    'aWdSBGZsYWcSHwoLc3BlY2lhbF9kbXMYBiADKAlSCnNwZWNpYWxEbXMSGwoJY2hlY2tfYm94GA'
    'cgASgIUghjaGVja0JveBIUCgVjb3VudBgIIAEoA1IFY291bnQSSwoKY29tbWFuZERtcxgJIAMo'
    'CzIrLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLkNvbW1hbmREbVIKY29tbWFuZE'
    'RtcxJbCg1wbGF5ZXJfY29uZmlnGAogASgLMjYuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2Uu'
    'ZG0udjEuRGFubXVXZWJQbGF5ZXJDb25maWdSDHBsYXllckNvbmZpZxIyChVyZXBvcnRfZmlsdG'
    'VyX2NvbnRlbnQYCyADKAlSE3JlcG9ydEZpbHRlckNvbnRlbnQSTwoLZXhwcmVzc2lvbnMYDCAD'
    'KAsyLS5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5FeHByZXNzaW9uc1ILZXhwcm'
    'Vzc2lvbnMSSgoKcG9zdF9wYW5lbBgNIAMoCzIrLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNl'
    'LmRtLnYxLlBvc3RQYW5lbFIJcG9zdFBhbmVsEiMKDWFjdGl2aXR5X21ldGEYDiADKAlSDGFjdG'
    'l2aXR5TWV0YQ==');

@$core.Deprecated('Use expoReportDescriptor instead')
const ExpoReport$json = {
  '1': 'ExpoReport',
  '2': [
    {'1': 'should_report_at_end', '3': 1, '4': 1, '5': 8, '10': 'shouldReportAtEnd'},
  ],
};

/// Descriptor for `ExpoReport`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List expoReportDescriptor = $convert.base64Decode(
    'CgpFeHBvUmVwb3J0Ei8KFHNob3VsZF9yZXBvcnRfYXRfZW5kGAEgASgIUhFzaG91bGRSZXBvcn'
    'RBdEVuZA==');

@$core.Deprecated('Use expressionDescriptor instead')
const Expression$json = {
  '1': 'Expression',
  '2': [
    {'1': 'keyword', '3': 1, '4': 3, '5': 9, '10': 'keyword'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'period', '3': 3, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.Period', '10': 'period'},
  ],
};

/// Descriptor for `Expression`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List expressionDescriptor = $convert.base64Decode(
    'CgpFeHByZXNzaW9uEhgKB2tleXdvcmQYASADKAlSB2tleXdvcmQSEAoDdXJsGAIgASgJUgN1cm'
    'wSQAoGcGVyaW9kGAMgAygLMiguYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuUGVy'
    'aW9kUgZwZXJpb2Q=');

@$core.Deprecated('Use expressionsDescriptor instead')
const Expressions$json = {
  '1': 'Expressions',
  '2': [
    {'1': 'data', '3': 1, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.Expression', '10': 'data'},
  ],
};

/// Descriptor for `Expressions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List expressionsDescriptor = $convert.base64Decode(
    'CgtFeHByZXNzaW9ucxJACgRkYXRhGAEgAygLMiwuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2'
    'UuZG0udjEuRXhwcmVzc2lvblIEZGF0YQ==');

@$core.Deprecated('Use inlinePlayerDanmakuSwitchDescriptor instead')
const InlinePlayerDanmakuSwitch$json = {
  '1': 'InlinePlayerDanmakuSwitch',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `InlinePlayerDanmakuSwitch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inlinePlayerDanmakuSwitchDescriptor = $convert.base64Decode(
    'ChlJbmxpbmVQbGF5ZXJEYW5tYWt1U3dpdGNoEhQKBXZhbHVlGAEgASgIUgV2YWx1ZQ==');

@$core.Deprecated('Use labelDescriptor instead')
const Label$json = {
  '1': 'Label',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'content', '3': 2, '4': 3, '5': 9, '10': 'content'},
  ],
};

/// Descriptor for `Label`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List labelDescriptor = $convert.base64Decode(
    'CgVMYWJlbBIUCgV0aXRsZRgBIAEoCVIFdGl0bGUSGAoHY29udGVudBgCIAMoCVIHY29udGVudA'
    '==');

@$core.Deprecated('Use labelV2Descriptor instead')
const LabelV2$json = {
  '1': 'LabelV2',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'content', '3': 2, '4': 3, '5': 9, '10': 'content'},
    {'1': 'exposure_once', '3': 3, '4': 1, '5': 8, '10': 'exposureOnce'},
    {'1': 'exposure_type', '3': 4, '4': 1, '5': 5, '10': 'exposureType'},
  ],
};

/// Descriptor for `LabelV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List labelV2Descriptor = $convert.base64Decode(
    'CgdMYWJlbFYyEhQKBXRpdGxlGAEgASgJUgV0aXRsZRIYCgdjb250ZW50GAIgAygJUgdjb250ZW'
    '50EiMKDWV4cG9zdXJlX29uY2UYAyABKAhSDGV4cG9zdXJlT25jZRIjCg1leHBvc3VyZV90eXBl'
    'GAQgASgFUgxleHBvc3VyZVR5cGU=');

@$core.Deprecated('Use periodDescriptor instead')
const Period$json = {
  '1': 'Period',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 2, '4': 1, '5': 3, '10': 'end'},
  ],
};

/// Descriptor for `Period`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List periodDescriptor = $convert.base64Decode(
    'CgZQZXJpb2QSFAoFc3RhcnQYASABKANSBXN0YXJ0EhAKA2VuZBgCIAEoA1IDZW5k');

@$core.Deprecated('Use playerDanmakuAiRecommendedLevelDescriptor instead')
const PlayerDanmakuAiRecommendedLevel$json = {
  '1': 'PlayerDanmakuAiRecommendedLevel',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuAiRecommendedLevel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuAiRecommendedLevelDescriptor = $convert.base64Decode(
    'Ch9QbGF5ZXJEYW5tYWt1QWlSZWNvbW1lbmRlZExldmVsEhQKBXZhbHVlGAEgASgIUgV2YWx1ZQ'
    '==');

@$core.Deprecated('Use playerDanmakuAiRecommendedLevelV2Descriptor instead')
const PlayerDanmakuAiRecommendedLevelV2$json = {
  '1': 'PlayerDanmakuAiRecommendedLevelV2',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 5, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuAiRecommendedLevelV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuAiRecommendedLevelV2Descriptor = $convert.base64Decode(
    'CiFQbGF5ZXJEYW5tYWt1QWlSZWNvbW1lbmRlZExldmVsVjISFAoFdmFsdWUYASABKAVSBXZhbH'
    'Vl');

@$core.Deprecated('Use playerDanmakuAiRecommendedSwitchDescriptor instead')
const PlayerDanmakuAiRecommendedSwitch$json = {
  '1': 'PlayerDanmakuAiRecommendedSwitch',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuAiRecommendedSwitch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuAiRecommendedSwitchDescriptor = $convert.base64Decode(
    'CiBQbGF5ZXJEYW5tYWt1QWlSZWNvbW1lbmRlZFN3aXRjaBIUCgV2YWx1ZRgBIAEoCFIFdmFsdW'
    'U=');

@$core.Deprecated('Use playerDanmakuBlockbottomDescriptor instead')
const PlayerDanmakuBlockbottom$json = {
  '1': 'PlayerDanmakuBlockbottom',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuBlockbottom`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuBlockbottomDescriptor = $convert.base64Decode(
    'ChhQbGF5ZXJEYW5tYWt1QmxvY2tib3R0b20SFAoFdmFsdWUYASABKAhSBXZhbHVl');

@$core.Deprecated('Use playerDanmakuBlockcolorfulDescriptor instead')
const PlayerDanmakuBlockcolorful$json = {
  '1': 'PlayerDanmakuBlockcolorful',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuBlockcolorful`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuBlockcolorfulDescriptor = $convert.base64Decode(
    'ChpQbGF5ZXJEYW5tYWt1QmxvY2tjb2xvcmZ1bBIUCgV2YWx1ZRgBIAEoCFIFdmFsdWU=');

@$core.Deprecated('Use playerDanmakuBlockrepeatDescriptor instead')
const PlayerDanmakuBlockrepeat$json = {
  '1': 'PlayerDanmakuBlockrepeat',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuBlockrepeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuBlockrepeatDescriptor = $convert.base64Decode(
    'ChhQbGF5ZXJEYW5tYWt1QmxvY2tyZXBlYXQSFAoFdmFsdWUYASABKAhSBXZhbHVl');

@$core.Deprecated('Use playerDanmakuBlockscrollDescriptor instead')
const PlayerDanmakuBlockscroll$json = {
  '1': 'PlayerDanmakuBlockscroll',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuBlockscroll`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuBlockscrollDescriptor = $convert.base64Decode(
    'ChhQbGF5ZXJEYW5tYWt1QmxvY2tzY3JvbGwSFAoFdmFsdWUYASABKAhSBXZhbHVl');

@$core.Deprecated('Use playerDanmakuBlockspecialDescriptor instead')
const PlayerDanmakuBlockspecial$json = {
  '1': 'PlayerDanmakuBlockspecial',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuBlockspecial`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuBlockspecialDescriptor = $convert.base64Decode(
    'ChlQbGF5ZXJEYW5tYWt1QmxvY2tzcGVjaWFsEhQKBXZhbHVlGAEgASgIUgV2YWx1ZQ==');

@$core.Deprecated('Use playerDanmakuBlocktopDescriptor instead')
const PlayerDanmakuBlocktop$json = {
  '1': 'PlayerDanmakuBlocktop',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuBlocktop`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuBlocktopDescriptor = $convert.base64Decode(
    'ChVQbGF5ZXJEYW5tYWt1QmxvY2t0b3ASFAoFdmFsdWUYASABKAhSBXZhbHVl');

@$core.Deprecated('Use playerDanmakuDomainDescriptor instead')
const PlayerDanmakuDomain$json = {
  '1': 'PlayerDanmakuDomain',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 2, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuDomain`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuDomainDescriptor = $convert.base64Decode(
    'ChNQbGF5ZXJEYW5tYWt1RG9tYWluEhQKBXZhbHVlGAEgASgCUgV2YWx1ZQ==');

@$core.Deprecated('Use playerDanmakuEnableblocklistDescriptor instead')
const PlayerDanmakuEnableblocklist$json = {
  '1': 'PlayerDanmakuEnableblocklist',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuEnableblocklist`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuEnableblocklistDescriptor = $convert.base64Decode(
    'ChxQbGF5ZXJEYW5tYWt1RW5hYmxlYmxvY2tsaXN0EhQKBXZhbHVlGAEgASgIUgV2YWx1ZQ==');

@$core.Deprecated('Use playerDanmakuOpacityDescriptor instead')
const PlayerDanmakuOpacity$json = {
  '1': 'PlayerDanmakuOpacity',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 2, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuOpacity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuOpacityDescriptor = $convert.base64Decode(
    'ChRQbGF5ZXJEYW5tYWt1T3BhY2l0eRIUCgV2YWx1ZRgBIAEoAlIFdmFsdWU=');

@$core.Deprecated('Use playerDanmakuScalingfactorDescriptor instead')
const PlayerDanmakuScalingfactor$json = {
  '1': 'PlayerDanmakuScalingfactor',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 2, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuScalingfactor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuScalingfactorDescriptor = $convert.base64Decode(
    'ChpQbGF5ZXJEYW5tYWt1U2NhbGluZ2ZhY3RvchIUCgV2YWx1ZRgBIAEoAlIFdmFsdWU=');

@$core.Deprecated('Use playerDanmakuSeniorModeSwitchDescriptor instead')
const PlayerDanmakuSeniorModeSwitch$json = {
  '1': 'PlayerDanmakuSeniorModeSwitch',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 5, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuSeniorModeSwitch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuSeniorModeSwitchDescriptor = $convert.base64Decode(
    'Ch1QbGF5ZXJEYW5tYWt1U2VuaW9yTW9kZVN3aXRjaBIUCgV2YWx1ZRgBIAEoBVIFdmFsdWU=');

@$core.Deprecated('Use playerDanmakuSpeedDescriptor instead')
const PlayerDanmakuSpeed$json = {
  '1': 'PlayerDanmakuSpeed',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 5, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuSpeed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuSpeedDescriptor = $convert.base64Decode(
    'ChJQbGF5ZXJEYW5tYWt1U3BlZWQSFAoFdmFsdWUYASABKAVSBXZhbHVl');

@$core.Deprecated('Use playerDanmakuSwitchDescriptor instead')
const PlayerDanmakuSwitch$json = {
  '1': 'PlayerDanmakuSwitch',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
    {'1': 'can_ignore', '3': 2, '4': 1, '5': 8, '10': 'canIgnore'},
  ],
};

/// Descriptor for `PlayerDanmakuSwitch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuSwitchDescriptor = $convert.base64Decode(
    'ChNQbGF5ZXJEYW5tYWt1U3dpdGNoEhQKBXZhbHVlGAEgASgIUgV2YWx1ZRIdCgpjYW5faWdub3'
    'JlGAIgASgIUgljYW5JZ25vcmU=');

@$core.Deprecated('Use playerDanmakuSwitchSaveDescriptor instead')
const PlayerDanmakuSwitchSave$json = {
  '1': 'PlayerDanmakuSwitchSave',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuSwitchSave`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuSwitchSaveDescriptor = $convert.base64Decode(
    'ChdQbGF5ZXJEYW5tYWt1U3dpdGNoU2F2ZRIUCgV2YWx1ZRgBIAEoCFIFdmFsdWU=');

@$core.Deprecated('Use playerDanmakuUseDefaultConfigDescriptor instead')
const PlayerDanmakuUseDefaultConfig$json = {
  '1': 'PlayerDanmakuUseDefaultConfig',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
  ],
};

/// Descriptor for `PlayerDanmakuUseDefaultConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playerDanmakuUseDefaultConfigDescriptor = $convert.base64Decode(
    'Ch1QbGF5ZXJEYW5tYWt1VXNlRGVmYXVsdENvbmZpZxIUCgV2YWx1ZRgBIAEoCFIFdmFsdWU=');

@$core.Deprecated('Use postPanelDescriptor instead')
const PostPanel$json = {
  '1': 'PostPanel',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 2, '4': 1, '5': 3, '10': 'end'},
    {'1': 'priority', '3': 3, '4': 1, '5': 3, '10': 'priority'},
    {'1': 'biz_id', '3': 4, '4': 1, '5': 3, '10': 'bizId'},
    {'1': 'biz_type', '3': 5, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.PostPanelBizType', '10': 'bizType'},
    {'1': 'click_button', '3': 6, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.ClickButton', '10': 'clickButton'},
    {'1': 'text_input', '3': 7, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.TextInput', '10': 'textInput'},
    {'1': 'check_box', '3': 8, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.CheckBox', '10': 'checkBox'},
    {'1': 'toast', '3': 9, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.Toast', '10': 'toast'},
  ],
};

/// Descriptor for `PostPanel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List postPanelDescriptor = $convert.base64Decode(
    'CglQb3N0UGFuZWwSFAoFc3RhcnQYASABKANSBXN0YXJ0EhAKA2VuZBgCIAEoA1IDZW5kEhoKCH'
    'ByaW9yaXR5GAMgASgDUghwcmlvcml0eRIVCgZiaXpfaWQYBCABKANSBWJpeklkEk0KCGJpel90'
    'eXBlGAUgASgOMjIuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuUG9zdFBhbmVsQm'
    'l6VHlwZVIHYml6VHlwZRJQCgxjbGlja19idXR0b24YBiABKAsyLS5iaWxpYmlsaS5jb21tdW5p'
    'dHkuc2VydmljZS5kbS52MS5DbGlja0J1dHRvblILY2xpY2tCdXR0b24SSgoKdGV4dF9pbnB1dB'
    'gHIAEoCzIrLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLlRleHRJbnB1dFIJdGV4'
    'dElucHV0EkcKCWNoZWNrX2JveBgIIAEoCzIqLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLm'
    'RtLnYxLkNoZWNrQm94UghjaGVja0JveBI9CgV0b2FzdBgJIAEoCzInLmJpbGliaWxpLmNvbW11'
    'bml0eS5zZXJ2aWNlLmRtLnYxLlRvYXN0UgV0b2FzdA==');

@$core.Deprecated('Use postPanelV2Descriptor instead')
const PostPanelV2$json = {
  '1': 'PostPanelV2',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 2, '4': 1, '5': 3, '10': 'end'},
    {'1': 'biz_type', '3': 3, '4': 1, '5': 5, '10': 'bizType'},
    {'1': 'click_button', '3': 4, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.ClickButtonV2', '10': 'clickButton'},
    {'1': 'text_input', '3': 5, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.TextInputV2', '10': 'textInput'},
    {'1': 'check_box', '3': 6, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.CheckBoxV2', '10': 'checkBox'},
    {'1': 'toast', '3': 7, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.ToastV2', '10': 'toast'},
    {'1': 'bubble', '3': 8, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.BubbleV2', '10': 'bubble'},
    {'1': 'label', '3': 9, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.LabelV2', '10': 'label'},
    {'1': 'post_status', '3': 10, '4': 1, '5': 5, '10': 'postStatus'},
  ],
};

/// Descriptor for `PostPanelV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List postPanelV2Descriptor = $convert.base64Decode(
    'CgtQb3N0UGFuZWxWMhIUCgVzdGFydBgBIAEoA1IFc3RhcnQSEAoDZW5kGAIgASgDUgNlbmQSGQ'
    'oIYml6X3R5cGUYAyABKAVSB2JpelR5cGUSUgoMY2xpY2tfYnV0dG9uGAQgASgLMi8uYmlsaWJp'
    'bGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuQ2xpY2tCdXR0b25WMlILY2xpY2tCdXR0b24STA'
    'oKdGV4dF9pbnB1dBgFIAEoCzItLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLlRl'
    'eHRJbnB1dFYyUgl0ZXh0SW5wdXQSSQoJY2hlY2tfYm94GAYgASgLMiwuYmlsaWJpbGkuY29tbX'
    'VuaXR5LnNlcnZpY2UuZG0udjEuQ2hlY2tCb3hWMlIIY2hlY2tCb3gSPwoFdG9hc3QYByABKAsy'
    'KS5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5Ub2FzdFYyUgV0b2FzdBJCCgZidW'
    'JibGUYCCABKAsyKi5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5CdWJibGVWMlIG'
    'YnViYmxlEj8KBWxhYmVsGAkgASgLMikuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udj'
    'EuTGFiZWxWMlIFbGFiZWwSHwoLcG9zdF9zdGF0dXMYCiABKAVSCnBvc3RTdGF0dXM=');

@$core.Deprecated('Use responseDescriptor instead')
const Response$json = {
  '1': 'Response',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseDescriptor = $convert.base64Decode(
    'CghSZXNwb25zZRISCgRjb2RlGAEgASgFUgRjb2RlEhgKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2'
    'U=');

@$core.Deprecated('Use subtitleItemDescriptor instead')
const SubtitleItem$json = {
  '1': 'SubtitleItem',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'id_str', '3': 2, '4': 1, '5': 9, '10': 'idStr'},
    {'1': 'lan', '3': 3, '4': 1, '5': 9, '10': 'lan'},
    {'1': 'lan_doc', '3': 4, '4': 1, '5': 9, '10': 'lanDoc'},
    {'1': 'subtitle_url', '3': 5, '4': 1, '5': 9, '10': 'subtitleUrl'},
    {'1': 'author', '3': 6, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.UserInfo', '10': 'author'},
    {'1': 'type', '3': 7, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.SubtitleType', '10': 'type'},
    {'1': 'lan_doc_brief', '3': 8, '4': 1, '5': 9, '10': 'lanDocBrief'},
    {'1': 'ai_type', '3': 9, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.SubtitleAiType', '10': 'aiType'},
    {'1': 'ai_status', '3': 10, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.SubtitleAiStatus', '10': 'aiStatus'},
  ],
};

/// Descriptor for `SubtitleItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subtitleItemDescriptor = $convert.base64Decode(
    'CgxTdWJ0aXRsZUl0ZW0SDgoCaWQYASABKANSAmlkEhUKBmlkX3N0chgCIAEoCVIFaWRTdHISEA'
    'oDbGFuGAMgASgJUgNsYW4SFwoHbGFuX2RvYxgEIAEoCVIGbGFuRG9jEiEKDHN1YnRpdGxlX3Vy'
    'bBgFIAEoCVILc3VidGl0bGVVcmwSQgoGYXV0aG9yGAYgASgLMiouYmlsaWJpbGkuY29tbXVuaX'
    'R5LnNlcnZpY2UuZG0udjEuVXNlckluZm9SBmF1dGhvchJCCgR0eXBlGAcgASgOMi4uYmlsaWJp'
    'bGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuU3VidGl0bGVUeXBlUgR0eXBlEiIKDWxhbl9kb2'
    'NfYnJpZWYYCCABKAlSC2xhbkRvY0JyaWVmEkkKB2FpX3R5cGUYCSABKA4yMC5iaWxpYmlsaS5j'
    'b21tdW5pdHkuc2VydmljZS5kbS52MS5TdWJ0aXRsZUFpVHlwZVIGYWlUeXBlEk8KCWFpX3N0YX'
    'R1cxgKIAEoDjIyLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYxLlN1YnRpdGxlQWlT'
    'dGF0dXNSCGFpU3RhdHVz');

@$core.Deprecated('Use textInputDescriptor instead')
const TextInput$json = {
  '1': 'TextInput',
  '2': [
    {'1': 'portrait_placeholder', '3': 1, '4': 3, '5': 9, '10': 'portraitPlaceholder'},
    {'1': 'landscape_placeholder', '3': 2, '4': 3, '5': 9, '10': 'landscapePlaceholder'},
    {'1': 'render_type', '3': 3, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.RenderType', '10': 'renderType'},
    {'1': 'placeholder_post', '3': 4, '4': 1, '5': 8, '10': 'placeholderPost'},
    {'1': 'show', '3': 5, '4': 1, '5': 8, '10': 'show'},
    {'1': 'avatar', '3': 6, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.Avatar', '10': 'avatar'},
    {'1': 'post_status', '3': 7, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.PostStatus', '10': 'postStatus'},
    {'1': 'label', '3': 8, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.Label', '10': 'label'},
  ],
};

/// Descriptor for `TextInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textInputDescriptor = $convert.base64Decode(
    'CglUZXh0SW5wdXQSMQoUcG9ydHJhaXRfcGxhY2Vob2xkZXIYASADKAlSE3BvcnRyYWl0UGxhY2'
    'Vob2xkZXISMwoVbGFuZHNjYXBlX3BsYWNlaG9sZGVyGAIgAygJUhRsYW5kc2NhcGVQbGFjZWhv'
    'bGRlchJNCgtyZW5kZXJfdHlwZRgDIAEoDjIsLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLm'
    'RtLnYxLlJlbmRlclR5cGVSCnJlbmRlclR5cGUSKQoQcGxhY2Vob2xkZXJfcG9zdBgEIAEoCFIP'
    'cGxhY2Vob2xkZXJQb3N0EhIKBHNob3cYBSABKAhSBHNob3cSQAoGYXZhdGFyGAYgAygLMiguYm'
    'lsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2UuZG0udjEuQXZhdGFyUgZhdmF0YXISTQoLcG9zdF9z'
    'dGF0dXMYByABKA4yLC5iaWxpYmlsaS5jb21tdW5pdHkuc2VydmljZS5kbS52MS5Qb3N0U3RhdH'
    'VzUgpwb3N0U3RhdHVzEj0KBWxhYmVsGAggASgLMicuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZp'
    'Y2UuZG0udjEuTGFiZWxSBWxhYmVs');

@$core.Deprecated('Use textInputV2Descriptor instead')
const TextInputV2$json = {
  '1': 'TextInputV2',
  '2': [
    {'1': 'portrait_placeholder', '3': 1, '4': 3, '5': 9, '10': 'portraitPlaceholder'},
    {'1': 'landscape_placeholder', '3': 2, '4': 3, '5': 9, '10': 'landscapePlaceholder'},
    {'1': 'render_type', '3': 3, '4': 1, '5': 14, '6': '.bilibili.community.service.dm.v1.RenderType', '10': 'renderType'},
    {'1': 'placeholder_post', '3': 4, '4': 1, '5': 8, '10': 'placeholderPost'},
    {'1': 'avatar', '3': 5, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.Avatar', '10': 'avatar'},
    {'1': 'text_input_limit', '3': 6, '4': 1, '5': 5, '10': 'textInputLimit'},
  ],
};

/// Descriptor for `TextInputV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textInputV2Descriptor = $convert.base64Decode(
    'CgtUZXh0SW5wdXRWMhIxChRwb3J0cmFpdF9wbGFjZWhvbGRlchgBIAMoCVITcG9ydHJhaXRQbG'
    'FjZWhvbGRlchIzChVsYW5kc2NhcGVfcGxhY2Vob2xkZXIYAiADKAlSFGxhbmRzY2FwZVBsYWNl'
    'aG9sZGVyEk0KC3JlbmRlcl90eXBlGAMgASgOMiwuYmlsaWJpbGkuY29tbXVuaXR5LnNlcnZpY2'
    'UuZG0udjEuUmVuZGVyVHlwZVIKcmVuZGVyVHlwZRIpChBwbGFjZWhvbGRlcl9wb3N0GAQgASgI'
    'Ug9wbGFjZWhvbGRlclBvc3QSQAoGYXZhdGFyGAUgAygLMiguYmlsaWJpbGkuY29tbXVuaXR5Ln'
    'NlcnZpY2UuZG0udjEuQXZhdGFyUgZhdmF0YXISKAoQdGV4dF9pbnB1dF9saW1pdBgGIAEoBVIO'
    'dGV4dElucHV0TGltaXQ=');

@$core.Deprecated('Use toastDescriptor instead')
const Toast$json = {
  '1': 'Toast',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'duration', '3': 2, '4': 1, '5': 5, '10': 'duration'},
    {'1': 'show', '3': 3, '4': 1, '5': 8, '10': 'show'},
    {'1': 'button', '3': 4, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.Button', '10': 'button'},
  ],
};

/// Descriptor for `Toast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toastDescriptor = $convert.base64Decode(
    'CgVUb2FzdBISCgR0ZXh0GAEgASgJUgR0ZXh0EhoKCGR1cmF0aW9uGAIgASgFUghkdXJhdGlvbh'
    'ISCgRzaG93GAMgASgIUgRzaG93EkAKBmJ1dHRvbhgEIAEoCzIoLmJpbGliaWxpLmNvbW11bml0'
    'eS5zZXJ2aWNlLmRtLnYxLkJ1dHRvblIGYnV0dG9u');

@$core.Deprecated('Use toastButtonV2Descriptor instead')
const ToastButtonV2$json = {
  '1': 'ToastButtonV2',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'action', '3': 2, '4': 1, '5': 5, '10': 'action'},
  ],
};

/// Descriptor for `ToastButtonV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toastButtonV2Descriptor = $convert.base64Decode(
    'Cg1Ub2FzdEJ1dHRvblYyEhIKBHRleHQYASABKAlSBHRleHQSFgoGYWN0aW9uGAIgASgFUgZhY3'
    'Rpb24=');

@$core.Deprecated('Use toastV2Descriptor instead')
const ToastV2$json = {
  '1': 'ToastV2',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'duration', '3': 2, '4': 1, '5': 5, '10': 'duration'},
    {'1': 'toast_button_v2', '3': 3, '4': 1, '5': 11, '6': '.bilibili.community.service.dm.v1.ToastButtonV2', '10': 'toastButtonV2'},
  ],
};

/// Descriptor for `ToastV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toastV2Descriptor = $convert.base64Decode(
    'CgdUb2FzdFYyEhIKBHRleHQYASABKAlSBHRleHQSGgoIZHVyYXRpb24YAiABKAVSCGR1cmF0aW'
    '9uElcKD3RvYXN0X2J1dHRvbl92MhgDIAEoCzIvLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNl'
    'LmRtLnYxLlRvYXN0QnV0dG9uVjJSDXRvYXN0QnV0dG9uVjI=');

@$core.Deprecated('Use userInfoDescriptor instead')
const UserInfo$json = {
  '1': 'UserInfo',
  '2': [
    {'1': 'mid', '3': 1, '4': 1, '5': 3, '10': 'mid'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sex', '3': 3, '4': 1, '5': 9, '10': 'sex'},
    {'1': 'face', '3': 4, '4': 1, '5': 9, '10': 'face'},
    {'1': 'sign', '3': 5, '4': 1, '5': 9, '10': 'sign'},
    {'1': 'rank', '3': 6, '4': 1, '5': 5, '10': 'rank'},
  ],
};

/// Descriptor for `UserInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userInfoDescriptor = $convert.base64Decode(
    'CghVc2VySW5mbxIQCgNtaWQYASABKANSA21pZBISCgRuYW1lGAIgASgJUgRuYW1lEhAKA3NleB'
    'gDIAEoCVIDc2V4EhIKBGZhY2UYBCABKAlSBGZhY2USEgoEc2lnbhgFIAEoCVIEc2lnbhISCgRy'
    'YW5rGAYgASgFUgRyYW5r');

@$core.Deprecated('Use videoMaskDescriptor instead')
const VideoMask$json = {
  '1': 'VideoMask',
  '2': [
    {'1': 'cid', '3': 1, '4': 1, '5': 3, '10': 'cid'},
    {'1': 'plat', '3': 2, '4': 1, '5': 5, '10': 'plat'},
    {'1': 'fps', '3': 3, '4': 1, '5': 5, '10': 'fps'},
    {'1': 'time', '3': 4, '4': 1, '5': 3, '10': 'time'},
    {'1': 'mask_url', '3': 5, '4': 1, '5': 9, '10': 'maskUrl'},
  ],
};

/// Descriptor for `VideoMask`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List videoMaskDescriptor = $convert.base64Decode(
    'CglWaWRlb01hc2sSEAoDY2lkGAEgASgDUgNjaWQSEgoEcGxhdBgCIAEoBVIEcGxhdBIQCgNmcH'
    'MYAyABKAVSA2ZwcxISCgR0aW1lGAQgASgDUgR0aW1lEhkKCG1hc2tfdXJsGAUgASgJUgdtYXNr'
    'VXJs');

@$core.Deprecated('Use videoSubtitleDescriptor instead')
const VideoSubtitle$json = {
  '1': 'VideoSubtitle',
  '2': [
    {'1': 'lan', '3': 1, '4': 1, '5': 9, '10': 'lan'},
    {'1': 'lanDoc', '3': 2, '4': 1, '5': 9, '10': 'lanDoc'},
    {'1': 'subtitles', '3': 3, '4': 3, '5': 11, '6': '.bilibili.community.service.dm.v1.SubtitleItem', '10': 'subtitles'},
  ],
};

/// Descriptor for `VideoSubtitle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List videoSubtitleDescriptor = $convert.base64Decode(
    'Cg1WaWRlb1N1YnRpdGxlEhAKA2xhbhgBIAEoCVIDbGFuEhYKBmxhbkRvYxgCIAEoCVIGbGFuRG'
    '9jEkwKCXN1YnRpdGxlcxgDIAMoCzIuLmJpbGliaWxpLmNvbW11bml0eS5zZXJ2aWNlLmRtLnYx'
    'LlN1YnRpdGxlSXRlbVIJc3VidGl0bGVz');


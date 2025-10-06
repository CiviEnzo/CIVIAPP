import 'package:flutter/foundation.dart';

@immutable
class ClientQuestionnaireTemplate {
  // ignore: prefer_const_constructors_in_immutables
  ClientQuestionnaireTemplate({
    required this.id,
    required this.salonId,
    required this.name,
    required List<ClientQuestionGroup> groups,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.isDefault = false,
  }) : groups = List.unmodifiable(groups);

  final String id;
  final String salonId;
  final String name;
  final List<ClientQuestionGroup> groups;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDefault;

  ClientQuestionnaireTemplate copyWith({
    String? id,
    String? salonId,
    String? name,
    List<ClientQuestionGroup>? groups,
    Object? description = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    bool? isDefault,
  }) {
    return ClientQuestionnaireTemplate(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      groups: groups ?? this.groups,
      description:
          description == _unset ? this.description : description as String?,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static const Object _unset = Object();
}

@immutable
class ClientQuestionGroup {
  // ignore: prefer_const_constructors_in_immutables
  ClientQuestionGroup({
    required this.id,
    required this.title,
    required List<ClientQuestionDefinition> questions,
    this.description,
    this.sortOrder = 0,
  }) : questions = List.unmodifiable(questions);

  final String id;
  final String title;
  final List<ClientQuestionDefinition> questions;
  final String? description;
  final int sortOrder;

  ClientQuestionGroup copyWith({
    String? id,
    String? title,
    List<ClientQuestionDefinition>? questions,
    Object? description = _unset,
    int? sortOrder,
  }) {
    return ClientQuestionGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      description:
          description == _unset ? this.description : description as String?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static const Object _unset = Object();
}

@immutable
class ClientQuestionDefinition {
  // ignore: prefer_const_constructors_in_immutables
  ClientQuestionDefinition({
    required this.id,
    required this.label,
    required this.type,
    List<ClientQuestionOption> options = const [],
    this.helperText,
    this.isRequired = false,
  }) : options = List.unmodifiable(options);

  final String id;
  final String label;
  final ClientQuestionType type;
  final List<ClientQuestionOption> options;
  final String? helperText;
  final bool isRequired;

  ClientQuestionDefinition copyWith({
    String? id,
    String? label,
    ClientQuestionType? type,
    List<ClientQuestionOption>? options,
    Object? helperText = _unset,
    bool? isRequired,
  }) {
    return ClientQuestionDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      options: options ?? this.options,
      helperText:
          helperText == _unset ? this.helperText : helperText as String?,
      isRequired: isRequired ?? this.isRequired,
    );
  }

  static const Object _unset = Object();
}

@immutable
class ClientQuestionOption {
  // ignore: prefer_const_constructors_in_immutables
  ClientQuestionOption({
    required this.id,
    required this.label,
    this.description,
  });

  final String id;
  final String label;
  final String? description;

  ClientQuestionOption copyWith({
    String? id,
    String? label,
    Object? description = _unset,
  }) {
    return ClientQuestionOption(
      id: id ?? this.id,
      label: label ?? this.label,
      description:
          description == _unset ? this.description : description as String?,
    );
  }

  static const Object _unset = Object();
}

@immutable
class ClientQuestionnaire {
  // ignore: prefer_const_constructors_in_immutables
  ClientQuestionnaire({
    required this.id,
    required this.clientId,
    required this.salonId,
    required this.templateId,
    required List<ClientQuestionAnswer> answers,
    required this.createdAt,
    required this.updatedAt,
  }) : answers = List.unmodifiable(answers);

  final String id;
  final String clientId;
  final String salonId;
  final String templateId;
  final List<ClientQuestionAnswer> answers;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientQuestionAnswer? answerFor(String questionId) {
    for (final answer in answers) {
      if (answer.questionId == questionId) {
        return answer;
      }
    }
    return null;
  }

  ClientQuestionnaire copyWith({
    String? id,
    String? clientId,
    String? salonId,
    String? templateId,
    List<ClientQuestionAnswer>? answers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientQuestionnaire(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      salonId: salonId ?? this.salonId,
      templateId: templateId ?? this.templateId,
      answers: answers ?? this.answers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class ClientQuestionAnswer {
  // ignore: prefer_const_constructors_in_immutables
  ClientQuestionAnswer({
    required this.questionId,
    this.boolValue,
    this.textValue,
    List<String> optionIds = const [],
    this.numberValue,
    this.dateValue,
  }) : optionIds = List.unmodifiable(optionIds);

  final String questionId;
  final bool? boolValue;
  final String? textValue;
  final List<String> optionIds;
  final num? numberValue;
  final DateTime? dateValue;

  bool get hasValue {
    if (boolValue != null) {
      return true;
    }
    if (textValue != null && textValue!.trim().isNotEmpty) {
      return true;
    }
    if (optionIds.isNotEmpty) {
      return true;
    }
    if (numberValue != null) {
      return true;
    }
    if (dateValue != null) {
      return true;
    }
    return false;
  }

  ClientQuestionAnswer copyWith({
    String? questionId,
    Object? boolValue = _unset,
    Object? textValue = _unset,
    List<String>? optionIds,
    Object? numberValue = _unset,
    Object? dateValue = _unset,
  }) {
    return ClientQuestionAnswer(
      questionId: questionId ?? this.questionId,
      boolValue: boolValue == _unset ? this.boolValue : boolValue as bool?,
      textValue: textValue == _unset ? this.textValue : textValue as String?,
      optionIds: optionIds ?? this.optionIds,
      numberValue:
          numberValue == _unset ? this.numberValue : numberValue as num?,
      dateValue: dateValue == _unset ? this.dateValue : dateValue as DateTime?,
    );
  }

  static const Object _unset = Object();
}

enum ClientQuestionType {
  boolean,
  text,
  textarea,
  singleChoice,
  multiChoice,
  number,
  date,
}

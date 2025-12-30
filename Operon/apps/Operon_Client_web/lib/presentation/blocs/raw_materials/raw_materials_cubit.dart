import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RawMaterialsState extends BaseState {
  const RawMaterialsState({
    super.status = ViewStatus.initial,
    this.materials = const [],
    this.message,
  }) : super(message: message);

  final List<RawMaterial> materials;
  @override
  final String? message;

  @override
  RawMaterialsState copyWith({
    ViewStatus? status,
    List<RawMaterial>? materials,
    String? message,
  }) {
    return RawMaterialsState(
      status: status ?? this.status,
      materials: materials ?? this.materials,
      message: message ?? this.message,
    );
  }
}

class RawMaterialsCubit extends Cubit<RawMaterialsState> {
  RawMaterialsCubit({
    required RawMaterialsRepository repository,
    required String orgId,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  })  : _repository = repository,
        _orgId = orgId,
        _canCreate = canCreate,
        _canEdit = canEdit,
        _canDelete = canDelete,
        super(const RawMaterialsState()) {
    loadRawMaterials();
  }

  final RawMaterialsRepository _repository;
  final String _orgId;
  final bool _canCreate;
  final bool _canEdit;
  final bool _canDelete;

  bool get canManage => _canCreate || _canEdit || _canDelete;
  bool get canCreate => _canCreate;
  bool get canEdit => _canEdit;
  bool get canDelete => _canDelete;

  Future<void> loadRawMaterials() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final materials = await _repository.fetchRawMaterials(_orgId);
      emit(state.copyWith(status: ViewStatus.success, materials: materials));
    } catch (e) {
      debugPrint('[RawMaterialsCubit] Error loading raw materials: $e');
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load raw materials: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> createRawMaterial(RawMaterial material) async {
    if (!_canCreate) return;
    try {
      await _repository.createRawMaterial(_orgId, material);
      await loadRawMaterials();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create raw material.',
      ));
    }
  }

  Future<void> updateRawMaterial(RawMaterial material) async {
    if (!_canEdit) return;
    try {
      await _repository.updateRawMaterial(_orgId, material);
      await loadRawMaterials();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update raw material.',
      ));
    }
  }

  Future<void> deleteRawMaterial(String materialId) async {
    if (!_canDelete) return;
    try {
      await _repository.deleteRawMaterial(_orgId, materialId);
      await loadRawMaterials();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete raw material.',
      ));
    }
  }
}


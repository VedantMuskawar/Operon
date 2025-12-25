import 'package:core_bloc/core_bloc.dart';
import 'package:dash_superadmin/domain/entities/admin_form.dart';
import 'package:dash_superadmin/domain/entities/organization_form.dart';
import 'package:dash_superadmin/domain/usecases/register_organization_with_admin.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'create_org_event.dart';
part 'create_org_state.dart';

class CreateOrgBloc extends BaseBloc<CreateOrgEvent, CreateOrgState> {
  CreateOrgBloc({
    required RegisterOrganizationWithAdminUseCase registerUseCase,
  })  : _registerUseCase = registerUseCase,
        super(const CreateOrgState()) {
    on<CreateOrgSubmitted>(_onSubmitted);
    on<CreateOrgReset>(_onReset);
  }

  final RegisterOrganizationWithAdminUseCase _registerUseCase;

  Future<void> _onSubmitted(
    CreateOrgSubmitted event,
    Emitter<CreateOrgState> emit,
  ) async {
    final errors = _validate(event);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Please fix the highlighted fields.',
          fieldErrors: errors,
          isSuccess: false,
          resetIdentifiers: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ViewStatus.loading,
        message: null,
        resetErrors: true,
        resetIdentifiers: true,
        isSuccess: false,
      ),
    );

    try {
      final businessId = event.businessId?.trim();
      final result = await _registerUseCase.call(
        organization: OrganizationForm(
          name: event.organizationName.trim(),
          industry: event.industry.trim(),
          businessId:
              (businessId != null && businessId.isNotEmpty) ? businessId : null,
        ),
        admin: AdminForm(
          name: event.adminName.trim(),
          phone: event.adminPhone.trim(),
        ),
        creatorUserId: event.creatorUserId,
      );

      emit(
        state.copyWith(
          status: ViewStatus.success,
          message: 'Organization created successfully.',
          fieldErrors: const {},
          organizationId: result.organizationId,
          adminUserId: result.adminUserId,
          isSuccess: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to create organization. Please try again.',
          resetErrors: true,
          resetIdentifiers: true,
          isSuccess: false,
        ),
      );
    }
  }

  Future<void> _onReset(
    CreateOrgReset event,
    Emitter<CreateOrgState> emit,
  ) async {
    emit(const CreateOrgState());
  }

  Map<String, String> _validate(CreateOrgSubmitted event) {
    final errors = <String, String>{};

    if (event.organizationName.trim().length < 3) {
      errors['organizationName'] = 'Enter at least 3 characters.';
    }
    if (event.industry.trim().isEmpty) {
      errors['industry'] = 'Industry is required.';
    }
    if (event.adminName.trim().length < 3) {
      errors['adminName'] = 'Enter the admin\'s full name.';
    }

    final digits = event.adminPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      errors['adminPhone'] = 'Enter a valid 10-digit Indian number.';
    }

    if (event.creatorUserId.trim().isEmpty) {
      errors['creator'] = 'You must be signed in to create organizations.';
    }

    return errors;
  }
}


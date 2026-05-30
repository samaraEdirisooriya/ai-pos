import 'package:equatable/equatable.dart';

class ClientsState extends Equatable {
  final bool loading;
  final List<dynamic> clients;
  final int page;
  final int limit;
  final int total;
  final String? error;

  const ClientsState({this.loading = false, this.clients = const [], this.page = 1, this.limit = 20, this.total = 0, this.error});

  ClientsState copyWith({bool? loading, List<dynamic>? clients, int? page, int? limit, int? total, String? error}) {
    return ClientsState(
      loading: loading ?? this.loading,
      clients: clients ?? this.clients,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, clients, page, limit, total, error];
}

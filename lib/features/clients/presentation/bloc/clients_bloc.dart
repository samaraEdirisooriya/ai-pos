import 'package:flutter_bloc/flutter_bloc.dart';
import 'clients_event.dart';
import 'clients_state.dart';
import '../../data/clients_api.dart';

class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  final ClientsApi api;

  ClientsBloc({required this.api}) : super(const ClientsState()) {
    on<FetchClients>(_onFetch);
    on<LoadMoreClients>(_onLoadMore);
    on<RefreshClients>(_onRefresh);
  }

  Future<void> _onFetch(FetchClients event, Emitter<ClientsState> emit) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final res = await api.fetchClients(q: event.query, page: 1, limit: state.limit);
      if (res != null && res['success'] == true) {
        final List items = List.from(res['data'] ?? []);
        final meta = res['meta'] ?? {};
        emit(state.copyWith(loading: false, clients: items, page: 1, total: meta['total'] ?? items.length));
      } else {
        emit(state.copyWith(loading: false, error: res?['error']?.toString() ?? 'Failed to fetch'));
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<void> _onLoadMore(LoadMoreClients event, Emitter<ClientsState> emit) async {
    if (state.loading) return;
    final next = state.page + 1;
    emit(state.copyWith(loading: true, error: null));
    try {
      final res = await api.fetchClients(page: next, limit: state.limit);
      if (res != null && res['success'] == true) {
        final List items = List.from(res['data'] ?? []);
        final all = List.from(state.clients)..addAll(items);
        final meta = res['meta'] ?? {};
        emit(state.copyWith(loading: false, clients: all, page: next, total: meta['total'] ?? all.length));
      } else {
        emit(state.copyWith(loading: false, error: res?['error']?.toString() ?? 'Failed to load more'));
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<void> _onRefresh(RefreshClients event, Emitter<ClientsState> emit) async {
    add(const FetchClients());
  }
}

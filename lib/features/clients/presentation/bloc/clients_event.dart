import 'package:equatable/equatable.dart';

abstract class ClientsEvent extends Equatable {
  const ClientsEvent();
  @override
  List<Object?> get props => [];
}

class FetchClients extends ClientsEvent {
  final String? query;
  const FetchClients({this.query});
  @override
  List<Object?> get props => [query];
}

class LoadMoreClients extends ClientsEvent {}

class RefreshClients extends ClientsEvent {}

class SelectClient extends ClientsEvent {
  final String clientId;
  const SelectClient(this.clientId);
  @override
  List<Object?> get props => [clientId];
}

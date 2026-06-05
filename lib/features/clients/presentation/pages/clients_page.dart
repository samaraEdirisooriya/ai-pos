import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/clients_api.dart';
import '../bloc/clients_bloc.dart';
import '../bloc/clients_event.dart';
import '../bloc/clients_state.dart';
import 'add_client_screen.dart';
import 'client_detail_page.dart';

class ClientsPageWrapper extends StatelessWidget {
  const ClientsPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ClientsBloc(api: ClientsApi())..add(const FetchClients()),
      child: const ClientsPage(),
    );
  }
}

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _shimmerController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _scrollController.addListener(() {
      try {
        final state = context.read<ClientsBloc>().state;
        if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 300) {
          if (!state.loading && state.clients.length < state.total) {
            context.read<ClientsBloc>().add(LoadMoreClients());
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openAddClient() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClientScreen()));
    if (res == true) context.read<ClientsBloc>().add(const FetchClients());
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => context.read<ClientsBloc>().add(FetchClients(query: v)),
      style: GoogleFonts.inter(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: 'Search clients...',
        hintStyle: GoogleFonts.inter(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: _openAddClient,
      icon: const Icon(Icons.person_add, color: Colors.black),
      label: Text('Add Client', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black)),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return BlocBuilder<ClientsBloc, ClientsState>(
          builder: (context, state) {
            Widget headerContent = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchField(),
                        const SizedBox(height: 12),
                        _buildAddButton(),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildSearchField()),
                        const SizedBox(width: 12),
                        _buildAddButton(),
                      ],
                    ),
            );

            return ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                headerContent,
                state.loading && state.clients.isEmpty
                    ? GridView.builder(
                        padding: EdgeInsets.all(isMobile ? 12 : 24),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: isMobile ? double.infinity : 200,
                          childAspectRatio: isMobile ? 3.2 : 1.5,
                          crossAxisSpacing: isMobile ? 8 : 16,
                          mainAxisSpacing: isMobile ? 8 : 16,
                        ),
                        itemCount: 8,
                        itemBuilder: (context, index) => _buildShimmerCard(),
                      )
                    : Column(
                        children: [
                          GridView.builder(
                            padding: EdgeInsets.all(isMobile ? 12 : 24),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: isMobile ? double.infinity : 200,
                              childAspectRatio: isMobile ? 3.2 : 1.5,
                              crossAxisSpacing: isMobile ? 8 : 16,
                              mainAxisSpacing: isMobile ? 8 : 16,
                            ),
                            itemCount: state.clients.length,
                            itemBuilder: (context, index) {
                              final c = state.clients[index];
                              return InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailPage(clientId: c['client_id']))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08), width: 1)),
                                  child: Row(children: [
                                    Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)), child: const Center(child: Icon(Icons.person, size: 24, color: Colors.white70))),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(c['name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(c['email'] ?? '-', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                                  ]),
                                ),
                              );
                            },
                          ),
                          if (state.clients.length < state.total)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: state.loading ? SizedBox(height: 48, child: Center(child: CircularProgressIndicator())) : const SizedBox.shrink(),
                            )
                        ],
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.0 - (1.0 - _shimmerController.value) * 2, 0),
              end: Alignment(1.0 + (1.0 - _shimmerController.value) * 2, 0),
              colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.06)],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 14, width: double.infinity, color: Colors.white.withOpacity(0.05)),
                      const SizedBox(height: 8),
                      Container(height: 10, width: 100, color: Colors.white.withOpacity(0.05)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

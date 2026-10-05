import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // gerado pelo comando: flutterfire configure

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BatalhaApp());
}

class BatalhaApp extends StatelessWidget {
  const BatalhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batalha de Ideias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatelessWidget {
  const TelaPrincipal({super.key});

  // Referência da coleção "ideias" no Cloud Firestore
  CollectionReference<Map<String, dynamic>> get _ideias =>
      FirebaseFirestore.instance.collection('ideias');

  // ---------- VOTAR ----------
  // FieldValue.increment evita erro quando duas pessoas votam ao mesmo tempo
  Future<void> _votar(String id) {
    return _ideias.doc(id).update({'votos': FieldValue.increment(1)});
  }

  // ---------- EXCLUIR ----------
  Future<void> _excluir(BuildContext context, String id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir ideia'),
        content: Text(
            'Deseja excluir "$titulo"? Ela sumirá para todos os usuários.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _ideias.doc(id).delete();
    }
  }

  // ---------- CADASTRAR ----------
  Future<void> _abrirCadastro(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final tituloCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();
    final autorCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova ideia'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o título'
                      : null,
                ),
                TextFormField(
                  controller: descricaoCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a descrição'
                      : null,
                ),
                TextFormField(
                  controller: autorCtrl,
                  decoration: const InputDecoration(labelText: 'Autor'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o autor'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _ideias.add({
                'titulo': tituloCtrl.text.trim(),
                'descricao': descricaoCtrl.text.trim(),
                'autor': autorCtrl.text.trim(),
                'votos': 0, // toda ideia nova começa com 0 votos
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚔️ Batalha de Ideias'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirCadastro(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova ideia'),
      ),
      // StreamBuilder = atualização em tempo real para todos os usuários
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ideias.orderBy('votos', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                  'Nenhuma ideia cadastrada ainda.\nToque em "Nova ideia"!',
                  textAlign: TextAlign.center),
            );
          }

          // Como a lista vem ordenada por votos, a primeira é a mais votada
          final top = docs.first.data();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              _CardRanking(
                titulo: top['titulo'] ?? '',
                votos: (top['votos'] ?? 0) as int,
              ),
              const SizedBox(height: 16),
              for (final doc in docs)
                _CardIdeia(
                  titulo: doc['titulo'] ?? '',
                  descricao: doc['descricao'] ?? '',
                  autor: doc['autor'] ?? '',
                  votos: (doc['votos'] ?? 0) as int,
                  onVotar: () => _votar(doc.id),
                  onExcluir: () =>
                      _excluir(context, doc.id, doc['titulo'] ?? ''),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CardRanking extends StatelessWidget {
  final String titulo;
  final int votos;
  const _CardRanking({required this.titulo, required this.votos});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade100,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('🏆 IDEIA MAIS VOTADA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(titulo,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('$votos ${votos == 1 ? 'voto' : 'votos'}',
                style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _CardIdeia extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String autor;
  final int votos;
  final VoidCallback onVotar;
  final VoidCallback onExcluir;

  const _CardIdeia({
    required this.titulo,
    required this.descricao,
    required this.autor,
    required this.votos,
    required this.onVotar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('💡 $titulo',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onExcluir,
                ),
              ],
            ),
            Text('Autor: $autor',
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(descricao),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('❤️ $votos ${votos == 1 ? 'voto' : 'votos'}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                FilledButton(onPressed: onVotar, child: const Text('VOTAR')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

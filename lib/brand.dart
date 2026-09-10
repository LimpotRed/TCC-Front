import 'package:flutter/material.dart';

// Cor de fundo da splash e do login.
const splashBackground = Color.fromARGB(255, 37, 69, 77);
// Cor dos títulos, botões e indicador de carregamento.
const brandColor = Color(0xFF30C5C9);

// Logo usada na splash e no login. Para trocar a imagem,
// substitua assets/images/image.png mantendo o nome do arquivo.
class GhydroLogo extends StatelessWidget {
  const GhydroLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ghydro',
      image: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/image.png',
            width: 160,
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ghydro',
            style: TextStyle(
              color: brandColor,
              fontSize: 42,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

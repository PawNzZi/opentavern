import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_app/core/macros.dart';
import 'package:tavern_app/core/models.dart';
import 'package:tavern_app/core/store.dart';
import 'package:tavern_app/data/demo.dart';

DemoCharacter _char({String name = '测试角色'}) => DemoCharacter(
      name: name,
      initial: '测',
      title: '',
      tagline: '',
      creator: '',
      version: '',
      description: '',
      greeting: '',
      tags: const [],
      lorebook: '',
      preset: '',
      chats: 0,
      tokens: '',
      colors: const [Color(0xFF6B4E3D)],
    );

void main() {
  test('persona overrides round-trip through JSON', () {
    final c = _char().copyWith(
      personaNameOverride: '姐夫',
      personaDescriptionOverride: '你是{{user}}。',
    );
    final back = DemoCharacter.fromJson(c.toJson());
    expect(back.personaNameOverride, '姐夫');
    expect(back.personaDescriptionOverride, '你是{{user}}。');
  });

  test('settingsForCharacter follows global when no persona override', () {
    final store = AppStore.instance;
    store.settings = const AppSettings(
      userName: '旅人',
      personaName: '旅人',
      personaDescription: '全局描述',
    );
    final eff = store.settingsForCharacter(_char());
    expect(eff.userName, '旅人');
    expect(eff.personaName, '旅人');
    expect(eff.personaDescription, '全局描述');
  });

  test('settingsForCharacter applies custom name and description', () {
    final store = AppStore.instance;
    store.settings = const AppSettings(
      userName: '旅人',
      personaName: '旅人',
      personaDescription: '全局描述',
    );
    final c = _char().copyWith(
      personaNameOverride: '姐夫',
      personaDescriptionOverride: '你是{{user}}，小姨子的姐夫。',
    );
    final eff = store.settingsForCharacter(c);
    expect(eff.userName, '姐夫');
    expect(eff.personaName, '姐夫');
    expect(eff.personaDescription, '你是{{user}}，小姨子的姐夫。');
  });

  test('settingsForCharacter handles name-only and description-only', () {
    final store = AppStore.instance;
    store.settings = const AppSettings(
      userName: '旅人',
      personaName: '旅人',
      personaDescription: '全局描述',
    );
    // 只有描述：名字/{{user}} 仍跟随全局。
    final d = store.settingsForCharacter(
      _char().copyWith(personaDescriptionOverride: '只改描述'),
    );
    expect(d.userName, '旅人');
    expect(d.personaDescription, '只改描述');
    // 只有名字：描述回退全局，{{user}} 用新名字。
    final n = store.settingsForCharacter(
      _char().copyWith(personaNameOverride: '新名字'),
    );
    expect(n.userName, '新名字');
    expect(n.personaDescription, '全局描述');
  });

  test('custom persona makes {{user}} resolve to its name', () {
    final store = AppStore.instance;
    store.settings = const AppSettings(
      userName: '旅人',
      personaName: '旅人',
      personaDescription: '全局描述',
    );
    final c = _char(name: '秦芷柔').copyWith(
      personaNameOverride: '姐夫',
      personaDescriptionOverride: '你是{{user}}，{{char}}的姐夫。',
    );
    final eff = store.settingsForCharacter(c);
    final out = MacroEngine.expand(
      eff.personaDescription,
      character: c,
      settings: eff,
    );
    expect(out, '你是姐夫，秦芷柔的姐夫。');
  });
}

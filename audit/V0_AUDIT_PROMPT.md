你是审计员。对照 DESIGN.md 与 V0 Acceptance 审当前 HEAD。不要扩需求。不要 push。不要 merge。
跑：godot --headless --path . --import --quit
跑：godot --headless --path . tests/test_runner.tscn
逐条 PASS/FAIL + 文件:行号。不以实现者说明为准。
必须成立：产钱、只能在已占房空格造硅酸 I、门口拆门、破门后才进房、拆光起步矿则败、炮把敌人打到 0 则胜、P1 驱逐仍在、无酸树后续档。
全 PASS 则打印 HEAD 并停止。有 FAIL 则只修该 FAIL、commit、再跑测试，然后停止。

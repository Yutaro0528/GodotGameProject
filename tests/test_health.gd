extends GdUnitTestSuite

## scripts/core/health.gd のテスト。
##
## Health は RefCounted 派生でシーンツリーに依存しないため、
## ヘッドレスでも高速かつ安定して回る。新しいロジックを足すときも
## この形（Node を経由しないテスト）を保つこと。

const __source := "res://scripts/core/health.gd"


func test_starts_at_full_hp() -> void:
	var health := Health.new(10)
	assert_int(health.get_current()).is_equal(10)
	assert_int(health.get_max()).is_equal(10)
	assert_bool(health.is_alive()).is_true()


func test_take_damage_reduces_current() -> void:
	var health := Health.new(10)
	var dealt := health.take_damage(3)
	assert_int(dealt).is_equal(3)
	assert_int(health.get_current()).is_equal(7)


func test_take_damage_clamps_at_zero() -> void:
	var health := Health.new(10)
	var dealt := health.take_damage(999)
	assert_int(dealt).is_equal(10)
	assert_int(health.get_current()).is_equal(0)
	assert_bool(health.is_alive()).is_false()


func test_heal_clamps_at_max() -> void:
	var health := Health.new(10)
	health.take_damage(4)
	var healed := health.heal(999)
	assert_int(healed).is_equal(4)
	assert_int(health.get_current()).is_equal(10)


func test_ratio() -> void:
	var health := Health.new(10)
	health.take_damage(5)
	assert_float(health.get_ratio()).is_equal_approx(0.5, 0.0001)


func test_enemy_stats_builds_health() -> void:
	var stats: EnemyStats = load("res://resources/enemies/slime.tres")
	var health := stats.create_health()
	assert_int(health.get_max()).is_equal(stats.max_hp)

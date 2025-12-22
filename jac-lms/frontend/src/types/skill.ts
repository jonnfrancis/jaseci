export interface SkillNode {
  topic_id: string;
  title: string;
  difficulty: number;
  mastery: number;
  prerequisites: string[];
  unlocked: boolean;
}

export interface SkillMapResponse {
  skill_map: SkillNode[];
}

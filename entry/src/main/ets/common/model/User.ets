export class User {
  id: number;
  username: string;
  passwordHash: string;
  createdAt: number;

  constructor(id: number, username: string, passwordHash: string, createdAt: number = Date.now()) {
    this.id = id;
    this.username = username;
    this.passwordHash = passwordHash;
    this.createdAt = createdAt;
  }
}
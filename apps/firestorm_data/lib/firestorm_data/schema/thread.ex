defmodule FirestormData.Thread do
  @moduledoc """
  A `Thread` is a series of related messages in response to the post that
  created the thread.
  """

  defmodule TitleSlug do
    @moduledoc """
    A configuration for turning thread titles into slugs.
    """

    use EctoAutoslugField.Slug, from: :title, to: :slug
  end

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias FirestormData.{Repo, Category, Post, View, Follow, Tagging, Tag, User}

  schema "threads" do
    belongs_to :category, Category
    field :title, :string
    field :slug, TitleSlug.Type
    has_many :posts, Post
    has_many :views, {"threads_views", View}, foreign_key: :assoc_id
    has_many :follows, {"threads_follows", Follow}, foreign_key: :assoc_id
    many_to_many :followers, User, join_through: "threads_follows", join_keys: [assoc_id: :id, user_id: :id]
    has_many :taggings, {"threads_taggings", Tagging}, foreign_key: :assoc_id
    many_to_many :tags, Tag, join_through: "threads_taggings", join_keys: [assoc_id: :id, tag_id: :id]

    timestamps()
  end

  @required_fields ~w(category_id title)a
  @optional_fields ~w(slug)a

  def changeset(record, params \\ %{}) do
    record
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> TitleSlug.maybe_generate_slug
    |> TitleSlug.unique_constraint
  end

  def user(nil) do
    {:error, "No first post!"}
  end
  def user(thread) do
    case first_post(thread) do
      nil -> {:error, "No first post"}
      p -> {:ok, p.user}
    end
  end

  def first_post(thread) do
    Post
    |> where([p], p.thread_id == ^thread.id)
    |> order_by(:inserted_at)
    |> limit(1)
    |> preload(:user)
    |> Repo.one
  end


  def completely_read?(thread, nil), do: false
  def completely_read?(thread, user) do
    unviewed_posts_count =
      thread
      |> unviewed_posts_query(user)
      |> select([p, _], p.id)
      |> Repo.aggregate(:count, :id)

    unviewed_posts_count == 0
  end

  def first_unread_post(thread, nil) do
    Post
    |> where([p], p.thread_id == ^thread.id)
    |> order_by([p], p.inserted_at)
    |> limit(1)
    |> Repo.one
  end
  def first_unread_post(thread, user) do
    fp =
      thread
      |> unviewed_posts_query(user)
      |> order_by([p], p.inserted_at)
      |> limit(1)
      |> Repo.one

    fp || first_unread_post(thread, nil)
  end

  def unviewed_posts_query(thread, user) do
    # find all posts with this thread id
    # where post id doesn't exist in posts_views with this user id
    Post
    |> where([p], p.thread_id == ^thread.id)
    |> join(:left, [p], post_view in "posts_views", [assoc_id: p.id, user_id: ^user.id])
    |> where([p, post_view], is_nil(post_view.id))
  end
end
